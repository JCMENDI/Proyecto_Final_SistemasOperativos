# 03 — Firewall UFW por servidor

> **Estado:** Diseño completado, scripts listos en `config/ufw/` · Aplicación pendiente
> **Responsable:** Cada quien en sus VMs (revisión cruzada al final)

## Política base

Todas las VMs aplican la misma política de partida:

- `ufw default deny incoming` — todo lo no autorizado se bloquea.
- `ufw default allow outgoing` — las VMs pueden iniciar conexiones libremente
  (necesario para `apt`, NTP, y para la comunicación entre servicios).

Esta política de **deny-by-default** es la única defensible en un ambiente
servidor: cualquier puerto que no esté explícitamente permitido queda
cerrado, incluso si un servicio mal configurado intenta escuchar en él.

## Matriz maestra de puertos abiertos

| Servidor | Puerto | Protocolo | Origen permitido | Razón |
|---|---|---|---|---|
| `bdd-server` | 22 | TCP | Laptop A, Laptop Luis | SSH administrativo |
| `bdd-server` | 3306 | TCP | `app-server` | MariaDB para la aplicación |
| `app-server` | 22 | TCP | Laptop A, Laptop Luis | SSH administrativo |
| `app-server` | 8000 | TCP | LAN `192.168.8.0/24` | API y frontend web |
| `elk-server` | 22 | TCP | Laptop A, Laptop José | SSH administrativo |
| `elk-server` | 5044 | TCP | `app-server` | Filebeat → Logstash |
| `elk-server` | 5601 | TCP | LAN `192.168.8.0/24` | Kibana UI |
| `zabbix-server` | 22 | TCP | Laptop A, Laptop José | SSH administrativo |
| `zabbix-server` | 80 | TCP | LAN `192.168.8.0/24` | Frontend Zabbix |
| `zabbix-server` | 10051 | TCP | LAN `192.168.8.0/24` | Agentes → server |

Puertos críticos que **no** están abiertos al exterior:

- Elasticsearch (`9200`) queda solo en loopback dentro de `elk-server`.
- La base de MariaDB que use Zabbix internamente (si decide local) queda solo
  en loopback.
- Ningún servidor expone ICMP a la WAN; ICMP entre la LAN se permite por
  defecto para diagnóstico.

## Regla del "host sin SSH a sus propias VMs"

El enunciado prohíbe que las laptops B y C tengan acceso SSH a las VMs que
hospedan. Esto se implementa de forma directa: cada VM **omite** de su lista
de orígenes SSH autorizados la IP de la laptop que la hospeda.

- `bdd-server` y `app-server` (hospedadas por José, `192.168.8.10`) solo
  aceptan SSH desde Laptop A y desde la laptop de Luis (`192.168.8.15`).
- `elk-server` y `zabbix-server` (hospedadas por Luis, `192.168.8.15`) solo
  aceptan SSH desde Laptop A y desde la laptop de José (`192.168.8.10`).

El resultado: una administración cruzada legítima, pero la laptop que aloja
una VM no puede entrar por SSH a esa misma VM (debe administrarla por
consola gráfica de VMware o, idealmente, vía la laptop del compañero).

## Plan de verificación

Desde Laptop A:

- `nmap -p 22,3306 192.168.8.20` debe mostrar 22 abierto y 3306 filtrado.
- `nmap -p 22,8000 192.168.8.21` debe mostrar ambos abiertos.
- `nmap -p 22,5601,5044 192.168.8.22` debe mostrar 22 y 5601 abiertos,
  5044 filtrado.
- `nmap -p 22,80,10051 192.168.8.23` debe mostrar los tres abiertos.

Desde la laptop de José hacia `bdd-server` y `app-server`:

- `ssh urlos@192.168.8.20` debe rechazar la conexión (puerto filtrado/rechazado).

Desde la laptop de Luis hacia `elk-server` y `zabbix-server`:

- `ssh urlos@192.168.8.22` debe rechazar igualmente.

## Por completar tras implementación

- [ ] Salida de `ufw status verbose` en cada uno de los 4 servidores.
- [ ] Resultados de `nmap` desde Laptop A a las 4 VMs.
- [ ] Captura del intento fallido de SSH desde el host hacia su propia VM.