# 07 — Servidor de Aplicación

> **Estado:** Diseño completado, código en `app/` listo · Despliegue pendiente
> **Responsable:** José (con revisión de Luis)

## Stack tecnológico y justificación

| Pieza | Tecnología | Razón |
|---|---|---|
| Lenguaje | Python 3.11 | Versión estable presente en Ubuntu 24.04 |
| Framework web | FastAPI | Async nativo (clave para soportar las compras masivas), docs auto-generadas en `/docs`, validación con Pydantic |
| ORM | SQLAlchemy 2.x | Estándar en Python, soporte nativo para MariaDB vía PyMySQL |
| Driver MariaDB | PyMySQL | Puro Python, no requiere compilación de extensiones C |
| Servidor ASGI | Uvicorn | El servidor de referencia para FastAPI |
| Templates | Jinja2 | Frontend mínimo HTML para la demostración manual |
| Logging | python-json-logger | Salida JSON estructurada lista para Filebeat |

## Modelo de despliegue

- **Usuario sistema:** `tienda` (sin shell de login). Evita correr la
  aplicación como `root` o como `urlos`, alineado con el principio de
  mínimo privilegio.
- **Layout de archivos en `app-server`:**
  - `/opt/tienda/` — código fuente clonado del repositorio.
  - `/opt/tienda/venv/` — entorno virtual con las dependencias.
  - `/opt/tienda/.env` — credenciales de BDD (permisos `600`, propietario `tienda`).
  - `/var/log/tienda/` — destino de los logs JSON que Filebeat envía a ELK.
- **Servicio systemd:** unit `tienda-api.service` con `Restart=on-failure`
  para sobrevivir caídas, y `EnvironmentFile=/opt/tienda/.env` para inyectar
  configuración sin hardcodear nada en el código.
- **Pruebas:** Swagger UI en `http://192.168.8.21:8000/docs` para inspección
  manual; frontend mínimo en `http://192.168.8.21:8000/` para la demostración.

## Criterios de fallo simulados

La aplicación implementa cinco condiciones que generan transacciones
fallidas, requisito explícito del enunciado. Los porcentajes son
configurables vía variables de entorno:

| Código | Cuándo dispara | Configurable |
|---|---|---|
| `INSUFFICIENT_STOCK` | Cantidad pedida > stock disponible para algún ítem | No (es determinista) |
| `PAYMENT_DECLINED` | Probabilidad aleatoria según `FAIL_RATE_PAYMENT` (default 15 %) | Sí |
| `GATEWAY_TIMEOUT` | Probabilidad aleatoria según `FAIL_RATE_TIMEOUT` (default 5 %) | Sí |
| `EMPTY_CART` | Checkout sobre un carrito sin ítems | No |
| `CART_NOT_FOUND` | El `cart_id` no existe o no pertenece al `user_id` | No |

Toda transacción, exitosa o fallida, se persiste en la tabla `orders`
(con `status` y `error_reason`) **y** se loguea como evento JSON. Los logs
son la fuente de verdad para el dashboard de Kibana; la tabla es para
consistencia transaccional.

## Plan de pruebas de carga

El script `app/scripts/load_test.py` genera tráfico variable:

- Para cada ronda crea un usuario aleatorio (`user_<hex>`).
- Crea un carrito, agrega entre 1 y 5 productos, en el 20 % de los casos
  remueve uno, y finalmente intenta el checkout.
- Las transacciones que pasan generan eventos `purchase.completed`; las
  que fallan generan `purchase.failed` con el `error_reason` correspondiente.

Para la demostración en vivo se ejecuta con `--rounds 500 --delay 0.05`
desde Laptop A, lo que produce volumen suficiente para que el dashboard de
Kibana muestre tendencias claras en menos de un minuto.

## Por completar tras implementación

- [ ] Captura del servicio `tienda-api.service` activo (`systemctl status`).
- [ ] Captura de Swagger UI accesible desde Laptop A.
- [ ] Captura del frontend HTML cargando productos.
- [ ] Resumen de salida de `load_test.py` (X exitosas, Y fallidas).a