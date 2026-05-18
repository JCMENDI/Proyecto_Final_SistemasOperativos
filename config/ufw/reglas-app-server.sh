#!/bin/bash
# reglas-app-server.sh — Reglas UFW para app-server
# Ejecutar como root en app-server

set -euo pipefail

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 8000/tcp
sudo ufw enable
sudo ufw status verbose