## Resumen ejecutivo

Este sistema implementa un entorno de servidores Linux interconectados que
soporta una aplicación web de venta de productos (Python/FastAPI + MariaDB),
con tres planos operativos: ejecución de la aplicación, monitoreo de
infraestructura con Zabbix, y centralización de logs estructurados en ELK
(Elasticsearch, Logstash, Kibana). La base de datos reside sobre un grupo
de volumen LVM construido encima de un arreglo RAID-1 (`mdadm`), y todas
las tareas operativas recurrentes (revisión de estado del servicio de BDD,
medición de recursos, copia de seguridad) están automatizadas con scripts
bash y `cron`. La autenticación entre equipos usa exclusivamente llaves SSH
y cada servidor expone únicamente los puertos necesarios mediante UFW.

**Tiempo estimado de despliegue desde cero:** entre 6 y 10 horas efectivas
para un operador con experiencia previa en Ubuntu, distribuidas
aproximadamente como:

| Fase | Tiempo aproximado |
|---|---|
| Red, VMs y conectividad básica | 1 h |
| Llaves SSH y firewall UFW | 1 h |
| Servidor BDD (LVM + RAID + MariaDB) | 1.5 h |
| Servidor Zabbix | 1.5 h |
| Servidor ELK | 2 h |
| Servidor de aplicación y despliegue de FastAPI | 1 h |
| Pipeline de logs y dashboard de Kibana | 1 h |
| Scripts bash, cron jobs y pruebas | 1 h |

---