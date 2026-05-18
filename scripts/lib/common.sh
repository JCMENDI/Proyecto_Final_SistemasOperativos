#!/bin/bash
# common.sh — Funciones compartidas entre scripts
# Uso: source /opt/so-project/scripts/lib/common.sh

LOG_DIR="/var/log/so-project"

log_csv() {
    local archivo=$1
    local linea=$2
    echo "$linea" >> "$LOG_DIR/$archivo"
}

check_service() {
    local servicio=$1
    if systemctl is-active --quiet "$servicio"; then
        echo "OK"
    else
        echo "ERROR"
    fi
}

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}