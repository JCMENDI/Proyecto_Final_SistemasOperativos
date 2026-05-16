# 01 — Red y Configuración de VMs

> **Estado:** Diseño completado · Implementación pendiente
> **Responsable:** José (laptop propia y VMs APP/BDD), Luis (laptop propia y VMs ELK/Zabbix)

## Plan de red

Se reutiliza el segmento `192.168.8.0/24` definido en la Tarea 6 para no
reconfigurar adaptadores ya validados. El modo de red de todas las VMs es
**Bridged**: cada VM aparece en la LAN física como un equipo más, condición
necesaria para que las VMs hospedadas en una laptop sean alcanzables desde
la otra laptop a través del switch. NAT no aplica porque ocultaría las VMs
detrás del host.

## Tabla de direcciones IP

| Equipo | IP | Función |
|---|---|---|
| Laptop A (admin/profesor) | `192.168.8.5` | Reservada para evaluación |
| Laptop José | `192.168.8.10` | Host de VMs `bdd-server` y `app-server` |
| Laptop Luis | `192.168.8.15` | Host de VMs `elk-server` y `zabbix-server` |
| VM `bdd-server` | `192.168.8.20` | MariaDB + RAID-1 |
| VM `app-server` | `192.168.8.21` | FastAPI + Filebeat |
| VM `elk-server` | `192.168.8.22` | Elasticsearch + Logstash + Kibana |
| VM `zabbix-server` | `192.168.8.23` | Zabbix server + frontend |

Sin gateway hacia internet desde las VMs durante la evaluación (red aislada);
las descargas de paquetes se hacen previamente con NAT temporal o desde un
repositorio espejo.

## Recursos asignados a cada VM

| VM | vCPU | RAM | Disco SO | Discos adicionales |
|---|---|---|---|---|
| `bdd-server` | 2 | 1.5 GB | 20 GB | 2 × 10 GB (RAID-1) + 1 × 10 GB (backups) |
| `app-server` | 2 | 1.5 GB | 20 GB | — |
| `elk-server` | 2 | 4 GB | 25 GB | — |
| `zabbix-server` | 2 | 1.5 GB | 20 GB | — |

Total agregado: 9 vCPU lógicos y ~8.5 GB de RAM. La distribución cruzada
(BDD+APP en laptop José, ELK+ZABBIX en laptop Luis) deja a cada host con
carga sostenible.

## Decisión Ubuntu 24.04 vs 22.04

Se usa **Ubuntu Server 24.04 LTS**. El enunciado lista 22.04, pero también
indica que se pueden usar las VMs ya empleadas en tareas previas (Tarea 6
fue con 24.04). 24.04 ofrece kernel y paquetes más recientes y los
repositorios oficiales de MariaDB, Zabbix y Elastic la soportan.

## Hostnames y resolución local

Cada VM tiene hostname acorde a su rol (`bdd-server`, `app-server`,
`elk-server`, `zabbix-server`). En `/etc/hosts` de las 4 VMs y de las 2
laptops se incluyen las 4 entradas para que la resolución no dependa de DNS.

## Procedimiento general (alto nivel)

1. Crear las 4 VMs en VMware Workstation Player con la ISO de Ubuntu 24.04.
2. Durante la instalación: usuario `urlos`, contraseña temporal, OpenSSH
   server marcado, sin Docker u otros snaps adicionales.
3. Configurar el adaptador de cada VM en modo **Bridged** y enlazarlo al
   adaptador físico Ethernet de la laptop.
4. Aplicar el `netplan` correspondiente (`config/netplan/<server>.yaml`) con
   la IP estática asignada.
5. Editar `/etc/hostname` y `/etc/hosts` en cada VM.
6. Verificar conectividad bidireccional con `ping` entre las 6 entidades
   (2 laptops + 4 VMs) y con SSH desde Laptop A hacia cada VM.

## Por completar tras implementación

- [ ] Capturas de la configuración del adaptador Bridged en VMware.
- [ ] Salida de `ip addr show` en cada VM.
- [ ] Salida de `ping -c 4` desde Laptop A a las 4 VMs.
- [ ] Capturas de `hostname` y `cat /etc/hosts` en cada VM.