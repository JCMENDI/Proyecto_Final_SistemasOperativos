# 00 — Arquitectura del Ambiente

## Resumen del proyecto

Sistema distribuido sobre cuatro servidores virtuales Ubuntu interconectados en
una LAN Ethernet que en conjunto ejecutan y monitorean una aplicación web de
venta de productos. La operación cubre tres planos:

- **Plano de negocio:** aplicación FastAPI (`app-server`) que persiste en
  MariaDB (`bdd-server`).
- **Plano de observabilidad:** centralización de logs en ELK (`elk-server`)
  y monitoreo de infraestructura en Zabbix (`zabbix-server`).
- **Plano de operación:** acceso administrativo por SSH con llaves desde
  Laptop A, automatización vía bash + cron, y firewall UFW restrictivo en
  cada servidor.

## Diagrama lógico

[ Laptop A — Admin ]
                      192.168.8.5
                          │  SSH con llave
          ┌───────────────┼───────────────────┐
          │                                   │
   Laptop José (192.168.8.10)         Laptop Luis (192.168.8.15)
   ┌────────────┬────────────┐         ┌────────────┬────────────┐
   │    BDD     │    APP     │         │    ELK     │   ZABBIX   │
   │ .8.20      │ .8.21      │         │ .8.22      │ .8.23      │
   │ MariaDB    │ FastAPI    │         │ ES+LS+K    │ srv+web    │
   │ +LVM RAID-1│ +Filebeat  │         │            │            │
   └────────────┴────────────┘         └────────────┴────────────┘
   Diagrama visual completo en `evidencias/diagrama-topologia.png`.

## Justificación de la distribución cruzada

Se optó por distribuir las VMs entre las dos laptops (no concentrarlas en una)
por dos razones:

1. **Capacidad de hardware:** ELK por sí solo consume 4–6 GB de RAM
   (Elasticsearch + Logstash + Kibana). Concentrar las 4 VMs exigiría una
   laptop con 16+ GB dedicados y dejaría al host sin margen.
2. **Cumplimiento del requisito "host sin SSH a sus propias VMs":** al
   distribuir cruzadamente, cada laptop administra las VMs del compañero
   (rol de Laptop A) sin violar la regla sobre sus propias VMs.

## Distribución de responsabilidades

| Componente | Responsable principal | Apoyo |
|---|---|---|
| Red física, switch, cableado | Ambos | — |
| Esquema de IPs y `/etc/hosts` | José | Luis |
| Configuración VMware en laptop José | José | — |
| Configuración VMware en laptop Luis | Luis | — |
| Llaves SSH (generación y distribución) | Ambos | — |
| Firewall UFW | Cada quien en sus VMs | Revisión cruzada |
| Servidor BDD (LVM + RAID + MariaDB) | José | Luis |
| Servidor APP (FastAPI + Filebeat) | José | Luis |
| Servidor ELK | Luis | José |
| Servidor Zabbix | Luis | José |
| Aplicación FastAPI (código + frontend) | José | Luis |
| Dashboard de Kibana | Luis | José |
| Scripts bash y cron jobs | Split por servidor | — |
| Documentación final | Ambos | — |

## Convenciones del proyecto

| Concepto | Valor |
|---|---|
| Subred | `192.168.8.0/24` |
| Sistema operativo VMs | Ubuntu Server 24.04 LTS |
| Hipervisor | VMware Workstation Player |
| Modo de red de las VMs | Bridged |
| Usuario administrativo en cada VM | `urlos` |
| Usuario de aplicación (BDD) | `tienda_app` |
| Usuario de respaldo (BDD) | `backup` |
| Algoritmo de llaves SSH | `ed25519` |
| Directorio raíz de scripts | `/opt/so-project/scripts/` |
| Directorio raíz de logs | `/var/log/so-project/` |
| Directorio de logs de aplicación | `/var/log/tienda/` |
| Directorio de backups BDD | `/mnt/backups/` |
| Datadir de MariaDB | `/mnt/db-data/mysql/` |

## Estándares de los scripts

Todo script bash entregado cumple con:

1. Cabecera con nombre, propósito, servidor, grupo desarrollador y uso.
2. `set -euo pipefail` para fallo temprano.
3. Salida en `/var/log/so-project/` en formato CSV con encabezado cuando aplique.
4. SSH remoto con `BatchMode=yes` y timeout corto.
5. Verificación de existencia de archivos remotos antes de transferir.