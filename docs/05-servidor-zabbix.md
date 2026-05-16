# 05 — Servidor Zabbix

> **Estado:** Diseño completado · Implementación pendiente
> **Responsable:** Luis (con revisión de José)

## Decisiones de arquitectura

- **Versión:** Zabbix 6.0 LTS. Se prefiere sobre 7.x por mayor estabilidad,
  documentación más madura y soporte extendido. La 6.0 cubre todos los
  requisitos del proyecto.
- **Backend de datos:** **MariaDB remota** en `bdd-server`, no instancia
  local. El enunciado sugiere compartir BDD por limitaciones de recursos,
  y esta decisión libera ~500 MB de RAM en `zabbix-server` y demuestra la
  comunicación inter-servidores (con sus reglas de firewall).
- **Frontend:** Apache + PHP-FPM (paquetes oficiales `zabbix-frontend-php`,
  `zabbix-apache-conf`). Apache es la opción documentada por defecto en la
  guía oficial de Zabbix para Ubuntu.

## Bases de datos en `bdd-server`

Se crean dos esquemas independientes en MariaDB:

| Esquema | Usuario | Origen permitido | Uso |
|---|---|---|---|
| `tienda` | `tienda_app` | `192.168.8.21` (app-server) | Datos de la aplicación |
| `zabbix` | `zabbix` | `192.168.8.23` (zabbix-server) | Estado y métricas de Zabbix |

La separación por usuario y origen garantiza que ni la app ni Zabbix puedan
ver datos del otro, aunque compartan instancia.

## Hosts monitoreados

Los cuatro servidores virtuales se registran como hosts en Zabbix:

| Host | Plantilla principal | Métricas clave |
|---|---|---|
| `bdd-server` | Linux by Zabbix agent | CPU, RAM, disco `/mnt/db-data`, estado de `mariadb.service` |
| `app-server` | Linux by Zabbix agent | CPU, RAM, estado de `tienda-api.service`, puerto 8000 reachable |
| `elk-server` | Linux by Zabbix agent | CPU, RAM, estado de `elasticsearch`, `logstash`, `kibana` |
| `zabbix-server` | Linux by Zabbix agent (self-monitoring) | Métricas del propio servidor y del proceso `zabbix-server` |

Además, en `zabbix-server` se configura un **item adicional de tipo log**
que apunta al directorio `/var/log/so-project/from-app-server/` donde
aterrizan los CSV de recursos de BDD enviados por `recursos-bdd.sh`. Esto
permite consultar el histórico en la propia UI de Zabbix.

## Plan de seguridad inicial

- Cambiar inmediatamente la contraseña por defecto del usuario `Admin`
  (`zabbix`) por una contraseña fuerte tras el primer login.
- Crear un usuario adicional con rol `User` (solo lectura) para
  demostraciones y reservar `Admin` para configuración.
- Frontend expuesto vía HTTP (no HTTPS) — decisión consciente para el
  ámbito del lab, documentada como **no apta para producción**.

## Por completar tras implementación

- [ ] Captura de los 4 hosts en estado verde en `Configuration → Hosts`.
- [ ] Captura del dashboard principal con gráficas de los 4 servidores.
- [ ] Captura del item de log con datos recibidos desde `app-server`.
- [ ] Salida de `systemctl status zabbix-server zabbix-agent2 apache2`.