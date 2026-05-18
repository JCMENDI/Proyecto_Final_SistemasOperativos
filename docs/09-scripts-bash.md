# 09 — Scripts Bash y Cron Jobs (José)

**Responsable:** José  
**VMs:** `bdd-server` y `app-server`  

---

## 1. Estructura de directorios

En ambas VMs se creó la misma estructura:

```bash
sudo mkdir -p /opt/so-project/scripts
sudo mkdir -p /var/log/so-project
sudo chown -R urlos:urlos /opt/so-project
sudo chown -R urlos:urlos /var/log/so-project
```

| Directorio | Propósito |
|---|---|
| `/opt/so-project/scripts/` | Scripts bash del proyecto |
| `/var/log/so-project/` | Logs en formato CSV |

---

## 2. Scripts en bdd-server

### 2.1 `backup.sh` — Respaldo de MariaDB

**Ubicación:** `/opt/so-project/scripts/backup.sh`  
**Propósito:** Genera un dump comprimido de la BD `tienda` en `/mnt/backups/`  

```bash
#!/bin/bash
set -euo pipefail

FECHA=$(date +%Y-%m-%d_%H-%M-%S)
DESTINO="/mnt/backups"
LOGFILE="/var/log/so-project/backup.csv"
DB="tienda"
USUARIO="backup"
CLAVE="backup_pass_2026"

mkdir -p "$DESTINO"

if [ ! -f "$LOGFILE" ]; then
    echo "timestamp,status,archivo,tamano_bytes" > "$LOGFILE"
fi

ARCHIVO="$DESTINO/tienda_$FECHA.sql.gz"

if mysqldump -u"$USUARIO" -p"$CLAVE" "$DB" | gzip > "$ARCHIVO"; then
    TAMANO=$(stat -c%s "$ARCHIVO")
    echo "$(date '+%Y-%m-%d %H:%M:%S'),OK,$ARCHIVO,$TAMANO" >> "$LOGFILE"
    echo "Backup exitoso: $ARCHIVO"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S'),ERROR,$ARCHIVO,0" >> "$LOGFILE"
    echo "Error en backup"
    exit 1
fi
```

**Prueba de ejecución:**

```bash
bash /opt/so-project/scripts/backup.sh
# Backup exitoso: /mnt/backups/tienda_2026-05-18_10-32-39.sql.gz
```

**Log generado (`/var/log/so-project/backup.csv`):**

```
timestamp,status,archivo,tamano_bytes
2026-05-18 10:32:40,OK,/mnt/backups/tienda_2026-05-18_10-32-39.sql.gz,985
```

---

### 2.2 `verify_raid.sh` — Verificación del RAID-1

**Ubicación:** `/opt/so-project/scripts/verify_raid.sh`  
**Propósito:** Verifica el estado del RAID-1 (`md127`) y lo registra en CSV  

```bash
#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/so-project/raid_status.csv"

if [ ! -f "$LOGFILE" ]; then
    echo "timestamp,dispositivo,estado" > "$LOGFILE"
fi

if grep -q "\[UU\]" /proc/mdstat; then
    ESTADO="OK"
elif grep -q "\[U_\]\|_U\]" /proc/mdstat; then
    ESTADO="DEGRADADO"
else
    ESTADO="DESCONOCIDO"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S'),md127,$ESTADO" >> "$LOGFILE"
echo "RAID md127: $ESTADO"
```

**Estados posibles:**

| Estado | Significado |
|---|---|
| `OK` | Ambos discos activos `[UU]` |
| `DEGRADADO` | Un disco falló `[U_]` o `[_U]` |
| `DESCONOCIDO` | No se pudo determinar |

**Log generado (`/var/log/so-project/raid_status.csv`):**

```
timestamp,dispositivo,estado
2026-05-18 10:37:59,md127,OK
```

---

## 3. Scripts en app-server

### 3.1 `health_check.sh` — Monitoreo de la aplicación

**Ubicación:** `/opt/so-project/scripts/health_check.sh`  
**Propósito:** Verifica que los endpoints de FastAPI respondan correctamente  

```bash
#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/so-project/health_check.csv"
URL="http://localhost:8000"

if [ ! -f "$LOGFILE" ]; then
    echo "timestamp,endpoint,status_code,latencia_ms,estado" > "$LOGFILE"
fi

check_endpoint() {
    local endpoint=$1
    local inicio=$(date +%s%3N)
    local status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL$endpoint" || echo "000")
    local fin=$(date +%s%3N)
    local latencia=$((fin - inicio))

    if [ "$status" = "200" ]; then
        ESTADO="OK"
    else
        ESTADO="ERROR"
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S'),$endpoint,$status,$latencia,$ESTADO" >> "$LOGFILE"
    echo "$endpoint → HTTP $status | ${latencia}ms | $ESTADO"
}

check_endpoint "/"
check_endpoint "/productos/"
check_endpoint "/pedidos/"
```

**Prueba de ejecución:**

```
/ → HTTP 200 | 78ms | OK
/productos/ → HTTP 200 | 23ms | OK
/pedidos/ → HTTP 200 | 17ms | OK
```

---

## 4. Cron Jobs

### 4.1 bdd-server (`crontab -l`)

```
# Backup diario a las 2:00 AM
0 2 * * * /bin/bash /opt/so-project/scripts/backup.sh

# Verificación del RAID cada hora
*/60 * * * * /bin/bash /opt/so-project/scripts/verify_raid.sh
```

### 4.2 app-server (`crontab -l`)

```
# Health check cada 5 minutos
*/5 * * * * /bin/bash /opt/so-project/scripts/health_check.sh
```

---

## 5. Resumen

| Script | VM | Frecuencia | Log |
|---|---|---|---|
| `backup.sh` | bdd-server | Diario 02:00 | `/var/log/so-project/backup.csv` |
| `verify_raid.sh` | bdd-server | Cada hora | `/var/log/so-project/raid_status.csv` |
| `health_check.sh` | app-server | Cada 5 min | `/var/log/so-project/health_check.csv` |