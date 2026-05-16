# 06 — Servidor ELK

> **Estado:** Diseño completado · Implementación pendiente
> **Responsable:** Luis (con revisión de José)

## Decisiones de arquitectura

- **Versión:** Elastic Stack **8.x**. Las tres piezas (Elasticsearch,
  Logstash, Kibana) y Filebeat se mantienen en la misma versión major
  para evitar incompatibilidades de protocolo.
- **Modo:** **single-node**. No es un clúster: una sola VM ejecuta toda la
  pila. Para un lab de un curso, alta disponibilidad es out-of-scope y
  multiplicaría los recursos requeridos.
- **Seguridad:** se habilita autenticación básica (xpack security
  encendido), con usuario `elastic` y contraseña fuerte. Se omite TLS/HTTPS
  por simplicidad — decisión documentada como inadecuada para producción
  pero aceptable para una red de laboratorio aislada.
- **Almacenamiento:** los datos viven en `/var/lib/elasticsearch` sobre el
  disco principal de la VM. No se requiere LVM aquí (el enunciado lo pide
  solo para el servidor de BDD).

## Tuning de memoria

`elk-server` tiene 4 GB de RAM. El reparto es crítico porque Elasticsearch
sobre la JVM es lo más sensible a memoria:

| Componente | Heap JVM | Memoria total estimada |
|---|---|---|
| Elasticsearch | 1 GB (`-Xms1g -Xmx1g`) | ~1.5 GB |
| Logstash | 512 MB (`LS_JAVA_OPTS="-Xmx512m"`) | ~750 MB |
| Kibana | (Node.js, no JVM) | ~500 MB |
| Sistema operativo + buffers | — | ~1.2 GB |

**Regla histórica:** dar a Elasticsearch JVM heap igual a la mitad de la RAM
disponible para él, sin exceder los 32 GB. En este caso, ~1 GB es suficiente
para los volúmenes esperados.

## Requisitos del sistema

Antes de instalar Elasticsearch hay que ajustar dos parámetros del kernel,
documentados como prerrequisitos por Elastic:

- `vm.max_map_count = 262144` (memoria virtual mapeada).
- `swappiness` bajo o swap desactivado (Elasticsearch sufre con swap).

Ambos se aplican vía `/etc/sysctl.d/`.

## Puertos expuestos

| Puerto | Proceso | Acceso |
|---|---|---|
| `9200` | Elasticsearch HTTP | Solo loopback de la propia VM |
| `9300` | Elasticsearch transport (no cluster, sin uso real) | Cerrado |
| `5044` | Logstash Beats input | Solo desde `app-server` (UFW) |
| `5601` | Kibana | LAN `192.168.8.0/24` (UFW) |

## Plan de índices y retención

- Patrón de índice: `tienda-YYYY.MM.dd` (un índice por día).
- Sin política ILM (Index Lifecycle Management): el lab es corto y no hay
  riesgo de saturar el disco.
- En Kibana se crea un *data view* `tienda-*` que agrupa todos los índices
  diarios.

## Plan de dashboards y visualizaciones

Detallado en `docs/08-pipeline-logs.md`. Resumen: un dashboard "Tienda —
Operaciones" con KPIs de éxito/falla, top razones de error, gráfica
temporal y tabla de transacciones fallidas.

## Por completar tras implementación

- [ ] `curl -u elastic:... http://localhost:9200/` con respuesta JSON exitosa.
- [ ] Captura del estado del clúster: `_cluster/health` → green o yellow.
- [ ] Captura del primer login en Kibana.
- [ ] Captura del data view `tienda-*` creado.
- [ ] Salida de `systemctl status elasticsearch logstash kibana`.