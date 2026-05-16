# 10 — Cron Jobs

> **Estado:** Diseño completado, crontabs en `config/cron/` · Instalación pendiente
> **Responsable:** José (crontab de app-server y bdd-server)

## Tabla maestra de tareas programadas

| Servidor | Schedule | Comando | Salida | Justificación de la frecuencia |
|---|---|---|---|---|
| `app-server` | `* * * * *` | `estado-servicio-bdd.sh` | `/var/log/so-project/estado-bdd.csv` | Detectar caída del servicio BDD en ≤ 1 minuto |
| `app-server` | `* * * * *` | `recursos-bdd.sh` | local + scp a `zabbix-server` | Métricas near-realtime para Zabbix |
| `app-server` | `*/5 * * * *` | `listar-conexiones-red.sh` | `/var/log/so-project/conexiones-establecidas.log` | Inventario periódico de conexiones; cada 5 min es suficiente |
| `bdd-server` | `30 2 * * *` | `backup-bdd.sh` | `/mnt/backups/` + scp a `app-server` | Backup diario en horario de baja actividad |

## Decisiones

- **Usuario que ejecuta:** `urlos`. Los scripts no requieren privilegios
  de `root` (acceso a `/var/log/so-project` y SSH con llave del usuario).
  Correr cron como `root` sería excederse.
- **Cada minuto para monitoreo:** balance entre granularidad y carga. Los
  scripts son ligeros (un SSH + lectura de `systemctl` o `top`), no
  saturan red ni CPU.
- **Backup a las 02:30 AM:** horario sin carga humana ni de pruebas. Si se
  cae el dump, el archivo de log de cron deja evidencia en
  `/var/log/syslog` para investigación al día siguiente.
- **Redirección a archivo de log de cron:** cada entrada redirige
  `stdout` y `stderr` (`>> ... 2>&1`) a un archivo dedicado de cron, no al
  mail local que nadie revisa.

## Instalación del crontab

Por usuario `urlos` en cada servidor, no como root. El archivo
`config/cron/crontab-app-server.txt` se carga con
`crontab <archivo>` desde el repositorio clonado, o sus líneas se pegan
manualmente en `crontab -e`.

## Verificación esperada

- `/var/log/syslog` debe mostrar líneas del estilo
  `CRON[...]: (urlos) CMD (/opt/so-project/scripts/...)` cada minuto.
- `tail -f /var/log/so-project/estado-bdd.csv` desde Laptop A muestra
  nuevas líneas aparecer en tiempo real.
- En el `zabbix-server`, el archivo
  `/var/log/so-project/from-app-server/recursos-bdd-<YYYYMMDD>.csv`
  crece progresivamente.
- A la mañana siguiente (post 02:30 AM), debe existir un archivo
  `tienda-<YYYYMMDD>_023000.sql.gz` en `/mnt/backups/` y replicado en
  `app-server:/var/backups/tienda/`.

## Por completar tras implementación

- [ ] Salida de `crontab -l -u urlos` en `app-server` y `bdd-server`.
- [ ] Capturas de `/var/log/syslog` mostrando ejecuciones.
- [ ] Capturas de los archivos de salida creciendo con `ls -la --full-time`.
- [ ] Captura del backup diario presente en ambos servidores tras pasar las 02:30 AM.