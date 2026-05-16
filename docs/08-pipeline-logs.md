# 08 — Pipeline de Logs Filebeat → ELK

> **Estado:** Diseño completado, configuración en `config/filebeat/` y `config/logstash/` · Implementación pendiente
> **Responsable:** Luis (ELK + Logstash + dashboard) · José (Filebeat en app-server)

## Diagrama del flujo

```
┌──────────────────────────────────┐         ┌──────────────────────────────────┐
│        app-server (192.8.21)     │         │        elk-server (192.8.22)     │
│                                  │         │                                  │
│  ┌────────────┐                  │         │   ┌──────────┐    ┌────────────┐│
│  │  FastAPI   │── escribe ──┐    │         │   │ Logstash │───►│ Elastic-   ││
│  │            │             ▼    │  TCP    │   │  :5044   │    │ search     ││
│  │            │  /var/log/tienda │  5044   │   │          │    │ :9200      ││
│  └────────────┘    /app.log      │ ──────► │   └──────────┘    └─────┬──────┘│
│                       │          │ JSON    │                         │       │
│  ┌────────────┐       │          │ por     │                  ┌──────▼──────┐│
│  │  Filebeat  │ ──────┘          │ línea   │                  │   Kibana    ││
│  │  (lee log) │                  │         │                  │    :5601    ││
│  └────────────┘                  │         │                  └─────────────┘│
└──────────────────────────────────┘         └──────────────────────────────────┘
```

## Esquema del log JSON

Cada línea escrita por la aplicación en `/var/log/tienda/app.log` es un
documento JSON con los siguientes campos. El esquema es contrato firme
entre la aplicación y los dashboards.

| Campo | Tipo | Obligatorio | Ejemplo |
|---|---|---|---|
| `timestamp` | string (ISO-8601) | sí | `2026-05-15T14:23:01` |
| `level` | string | sí | `INFO`, `WARNING`, `ERROR` |
| `logger` | string | sí | `tienda.orders` |
| `message` | string | sí | `Compra completada exitosamente` |
| `event` | string | sí | `purchase.completed`, `purchase.failed`, `cart.created` |
| `status` | enum | sí | `success`, `failed` |
| `transaction_id` | string (UUID) | si aplica | `a1b2c3d4-...` |
| `user_id` | string | si aplica | `user_3f8a` |
| `error_reason` | string | si `status=failed` | `PAYMENT_DECLINED` |
| `duration_ms` | int | si aplica | `42` |

Campos con prefijo `event` siguen el patrón `<área>.<acción>`:
`purchase.completed`, `purchase.failed`, `cart.created`, `cart.item_added`,
`cart.item_removed`, `app.start`, `app.stop`. Esto facilita filtros por
prefijo en Kibana.

## Configuración de Filebeat

Vive en `/etc/filebeat/filebeat.yml` (versión final en
`config/filebeat/filebeat.yml`). Puntos clave:

- Input `filestream` apuntando a `/var/log/tienda/app.log`.
- Parser `ndjson` que extrae las claves del JSON al nivel del documento.
- Output dirigido a `192.168.8.22:5044` (Logstash).
- Tags `["tienda", "proyecto-so", "2026"]` para filtrar fácilmente si en
  el futuro otras fuentes envían al mismo Logstash.

## Configuración de Logstash

Pipeline `pipeline-tienda.conf` en `/etc/logstash/conf.d/`. Tres etapas:

1. **Input:** `beats` en puerto `5044`.
2. **Filter:** conversión de `duration_ms` a entero, eliminación de
   metadatos verbosos de Beats, etiqueta `purchase` cuando el `event`
   empieza con `purchase.`.
3. **Output:** índice diario `tienda-YYYY.MM.dd` en Elasticsearch.

## Plan de dashboard en Kibana

Dashboard único llamado **"Tienda — Operaciones"** con las siguientes
visualizaciones:

| # | Tipo | Pregunta que responde |
|---|---|---|
| 1 | KPI / metric | Total de intentos de compra en el período seleccionado |
| 2 | KPI / metric | Porcentaje de compras exitosas |
| 3 | Gráfica de líneas | Compras por minuto, separadas por `status` |
| 4 | Barra horizontal | Top 5 `error_reason` (compras fallidas) |
| 5 | Tabla | Últimas 50 transacciones fallidas (timestamp, transaction_id, user_id, error_reason) |
| 6 | Histograma | Distribución de `duration_ms` para compras exitosas |

El KPI 2 y la visualización 4 son lo que el enunciado pide poder responder
"de manera rápida": **¿qué transacciones fallaron y por qué?**

## Decisiones notables

- **JSON estructurado desde origen** (no parsing por regex en Logstash):
  reduce CPU en Logstash y elimina ambigüedad. La app escribe lo que ELK
  necesita.
- **Filebeat en vez de Logstash directo en `app-server`:** Filebeat es
  liviano (~30 MB de RAM) y resiste cortes de red mediante su registro
  de offset persistente; Logstash es pesado y mejor concentrado en
  `elk-server`.
- **Persistencia paralela en BDD:** las órdenes fallidas se guardan también
  en la tabla `orders`, no solo en logs. ELK es para análisis;
  la BDD es para integridad transaccional.

## Por completar tras implementación

- [ ] Captura de Discover en Kibana mostrando eventos `purchase.*`.
- [ ] Capturas individuales de las 6 visualizaciones del dashboard.
- [ ] Captura del dashboard completo con tráfico real generado por `load_test.py`.
- [ ] Verificación de la cadena: provocar un fallo, verlo en Kibana en menos de 1 min.