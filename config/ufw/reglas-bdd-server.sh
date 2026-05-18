#!/bin/bash
# reglas-bdd-server.sh — Reglas UFW para bdd-server
# Ejecutar como root en bdd-server

set -euo pipefail

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow from 192.168.8.21 to any port 3306
sudo ufw enable
sudo ufw status verbose