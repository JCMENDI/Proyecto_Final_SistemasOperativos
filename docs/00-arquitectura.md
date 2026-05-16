# 00 — Arquitectura y División de Trabajo

## Topología de red

```
        192.168.8.5
        Laptop A (admin / evaluación)
               |
         [Switch físico]        ← requerido para Fase 2
        /                \
  192.168.8.10        192.168.8.15
  Laptop José          Laptop Luis
  /        \           /        \
.8.20     .8.21    .8.22      .8.23
bdd-server app-server elk-server zabbix-server
```

Todas las VMs corren en modo **Bridged** en VMware Workstation Player.
Sistema operativo: Ubuntu Server 24.04 LTS.

---

## División de responsabilidades

### Fase 1 — Sin switch (trabajo en paralelo, cada quien en su laptop)

#### José (laptop .8.10 · VMs .8.20 y .8.21)

| Tarea | Entregable | Estado |
|---|---|---|
| Crear VM bdd-server | VM corriendo, IP estática | ☐ |
| RAID-1 con mdadm (2 discos virtuales) | `/proc/mdstat` muestra md0 activo | ☐ |
| LVM sobre RAID-1 | `lvdisplay` muestra `db-data` montado en `/mnt/db-data` | ☐ |
| Instalar y configurar MariaDB | `systemctl status mariadb` activo, datadir en `/mnt/db-data/mysql` | ☐ |
| Usuarios MariaDB (`tienda_app`, `backup`) | Permisos verificados localmente | ☐ |
| UFW en bdd-server | Solo puerto 3306 abierto para .8.21 | ☐ |
| Crear VM app-server | VM corriendo, IP estática | ☐ |
| Código FastAPI completo | `app/` con modelos, rutas, templates, logs JSON | ☐ |
| Instalar dependencias Python + systemd | `systemctl status tienda` activo | ☐ |
| Instalar Filebeat | Configurado para enviar a `.8.22:5044` (pendiente prueba) | ☐ |
| UFW en app-server | Puertos 80, 443, 22 abiertos según política | ☐ |
| Scripts bash: `backup.sh` (BDD) | Genera dump cifrado en `/mnt/backups/` | ☐ |
| Scripts bash: `health_check.sh` (APP) | CSV en `/var/log/so-project/` | ☐ |
| Cron jobs en bdd-server | `crontab -l` muestra tareas programadas | ☐ |
| Documentación: `04-bdd-lvm-mariadb.md` | Completa con capturas | ☐ |
| Documentación: `07-servidor-aplicacion.md` | Completa con capturas | ☐ |
| Documentación: su sección en `09-scripts-bash.md` | Completa | ☐ |

#### Luis (laptop .8.15 · VMs .8.22 y .8.23)

| Tarea | Entregable | Estado |
|---|---|---|
| Crear VM elk-server | VM corriendo, IP estática | ☐ |
| Instalar Elasticsearch | `curl localhost:9200` responde | ☐ |
| Instalar Logstash | Pipeline `beats → elasticsearch` configurado (escuchando 5044) | ☐ |
| Instalar Kibana | `http://localhost:5601` accesible | ☐ |
| Index pattern en Kibana | `tienda-logs-*` creado | ☐ |
| Dashboard Kibana | Visualizaciones: compras exitosas vs fallidas, top errores, latencia | ☐ |
| UFW en elk-server | Puertos 9200, 5601, 5044 abiertos según política | ☐ |
| Crear VM zabbix-server | VM corriendo, IP estática | ☐ |
| Instalar Zabbix server + frontend | `http://localhost/zabbix` accesible | ☐ |
| Agente Zabbix local (en zabbix-server) | Host `zabbix-server` visible en frontend | ☐ |
| UFW en zabbix-server | Puerto 10051 abierto para agentes | ☐ |
| Scripts bash: `elk-status.sh` | Verifica salud de Elasticsearch + Logstash | ☐ |
| Scripts bash: `log-rotate.sh` | Rota índices viejos de Elasticsearch | ☐ |
| Cron jobs en elk-server | Tareas de mantenimiento programadas | ☐ |
| Documentación: `05-servidor-zabbix.md` | Completa con capturas | ☐ |
| Documentación: `06-servidor-elk.md` | Completa con capturas | ☐ |
| Documentación: `08-pipeline-logs.md` (arquitectura) | Completa (prueba queda para Fase 2) | ☐ |

---

### Fase 2 — Con switch (pruebas conjuntas)

> Estas tareas **requieren conectividad entre las dos laptops** a través del switch físico.
> Se realizan una vez que el switch esté disponible.

| Tarea | Responsable | Descripción |
|---|---|---|
| Verificar ping entre todas las IPs | Ambos | Todas las VMs se ven entre sí en la LAN |
| Llaves SSH (`02-llaves-ssh.md`) | Ambos | Generación y distribución de `ed25519` |
| UFW: regla SSH cruzada | Cada quien | Laptop A y compañero pueden entrar; host propio no |
| Filebeat → Logstash pipeline | José + Luis | Iniciar Filebeat en app-server; verificar índice en Kibana |
| Zabbix agentes remotos | Luis (+ José) | Instalar agente en bdd-server y app-server; hosts visibles en Zabbix |
| Prueba E2E de la tienda | Ambos | Crear compras desde Laptop A, ver logs en Kibana, alertas en Zabbix |
| `docs/01-red-y-vms.md` completo | Ambos | Incluir capturas de ping, `ip a`, tablas de enrutamiento |
| `manual-ejecucion.md` final | Ambos | Unir todas las secciones en el manual de entrega |

---

## Convenciones del proyecto

| Concepto | Valor |
|---|---|
| Subred | `192.168.8.0/24` |
| Sistema operativo VMs | Ubuntu Server 24.04 LTS |
| Hipervisor | VMware Workstation Player (modo Bridged) |
| Usuario admin en cada VM | `urlos` |
| Usuario de aplicación (BD) | `tienda_app` |
| Usuario de respaldo (BD) | `backup` |
| Algoritmo SSH | `ed25519` |
| Directorio scripts | `/opt/so-project/scripts/` |
| Logs de operación | `/var/log/so-project/` |
| Logs de aplicación | `/var/log/tienda/` |
| Backups BD | `/mnt/backups/` |
| Datadir MariaDB | `/mnt/db-data/mysql/` |

## Estándares de scripts bash

Todo script entregado debe cumplir:

1. Cabecera con nombre, propósito, servidor objetivo y uso.
2. `set -euo pipefail` para fallo temprano.
3. Salida en `/var/log/so-project/` en formato CSV con encabezado cuando aplique.
4. SSH remoto con `-o BatchMode=yes -o ConnectTimeout=5`.
5. Verificación de existencia de archivos remotos antes de transferir.