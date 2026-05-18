#!/bin/bash
set -euo pipefail

# backup-bdd.sh — Respaldo de MariaDB tienda
# Servidor: bdd-server (192.168.8.20)
# Uso: ./backup-bdd.sh
# Cron: 0 2 * * * /bin/bash /opt/so-project/scripts/backup-bdd.sh

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