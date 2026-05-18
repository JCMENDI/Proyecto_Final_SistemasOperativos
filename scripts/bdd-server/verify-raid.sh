#!/bin/bash
set -euo pipefail

# verify-raid.sh — Verifica estado del RAID-1
# Servidor: bdd-server (192.168.8.20)
# Uso: ./verify-raid.sh
# Cron: */60 * * * * /bin/bash /opt/so-project/scripts/verify-raid.sh

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