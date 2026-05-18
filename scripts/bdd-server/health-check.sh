#!/bin/bash
set -euo pipefail

# health-check.sh — Monitorea endpoints de FastAPI
# Servidor: app-server (192.168.8.21)
# Uso: ./health-check.sh
# Cron: */5 * * * * /bin/bash /opt/so-project/scripts/health-check.sh

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