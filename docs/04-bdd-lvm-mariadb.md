# 04 — Servidor BDD: RAID-1, LVM y MariaDB

> **Estado:** Diseño completado · Implementación pendiente
> **Responsable:** José (con revisión de Luis)

## Topología de discos

`bdd-server` se aprovisiona con cuatro discos virtuales independientes,
agregados en VMware Workstation:

| Dispositivo | Tamaño | Rol |
|---|---|---|
| `/dev/sda` | 20 GB | Sistema operativo Ubuntu (raíz, swap) |
| `/dev/sdb` | 10 GB | Miembro del RAID-1 para datos de MariaDB |
| `/dev/sdc` | 10 GB | Miembro del RAID-1 para datos de MariaDB |
| `/dev/sdd` | 10 GB | Disco separado para backups, montado en `/mnt/backups` |

El disco de backups es **independiente** del par RAID-1 para cumplir el
requisito del enunciado: "el backup se traslada hacia otro disco distinto al
usado para alojar los archivos de datos".

## Diseño de RAID + LVM

Sobre los dos discos del par se construye un arreglo **RAID-1** mediante
`mdadm`, expuesto como `/dev/md0`. Encima de `/dev/md0` se construye una
pila LVM:

- **Physical Volume:** `/dev/md0`.
- **Volume Group:** `vg-data` (incorpora únicamente este PV).
- **Logical Volume:** `lv-mysql` (consume todo el espacio disponible del VG).
- **Filesystem:** `ext4` con etiqueta `mysql-data`.
- **Mount point:** `/mnt/db-data`.
- **Datadir final de MariaDB:** `/mnt/db-data/mysql`.

La entrada en `/etc/fstab` usa la `UUID` del filesystem (no el path del LV)
para sobrevivir reordenamientos de discos.

## Decisiones de diseño y justificación

- **RAID-1 sobre RAID-0 o RAID-5:** el enunciado pide "grupo de volumen con
  al menos 2 discos"; la redundancia (objetivo del proyecto) la cumple
  RAID-1. RAID-0 no da redundancia; RAID-5 requiere mínimo 3 discos y
  agrega complejidad innecesaria.
- **`mdadm` en vez de LVM mirror:** `mdadm` es la implementación de RAID
  más común en Linux, mejor documentada y desacoplada de LVM. Permite
  reconstruir un disco sin afectar la capa LVM por encima.
- **LVM encima del RAID (y no a la inversa):** el RAID protege contra falla
  de disco a nivel de bloque; LVM permite redimensionar el filesystem en
  caliente si crece la BDD. El orden correcto es `discos → mdadm → LVM →
  filesystem`.
- **Datadir movido a `/mnt/db-data/mysql`:** los paquetes de MariaDB lo
  colocan por defecto en `/var/lib/mysql`, que vive en el disco del SO. Se
  reubica para que TODOS los archivos de datos residan sobre el volumen
  protegido por RAID, no solo lógicamente referenciados desde ahí.

## Esquema de la base de datos `tienda`

Cuatro tablas, definidas por el ORM de la aplicación:

| Tabla | Propósito | PK |
|---|---|---|
| `products` | Catálogo (SKU, nombre, precio, stock) | `id` |
| `carts` | Carritos abiertos por usuario | `id` |
| `cart_items` | Líneas de carrito (producto + cantidad) | `id`, FK a `carts` y `products` |
| `orders` | Transacciones completadas (exitosas y fallidas, con `error_reason`) | `id`, `transaction_id` único |

Las órdenes fallidas también se persisten (no solo se loguean) para que
exista una fuente de verdad en BDD además del índice de Elasticsearch.

## Usuarios de la BDD

| Usuario | Host de origen | Privilegios | Uso |
|---|---|---|---|
| `root` | `localhost` | Todos | Administración manual |
| `tienda_app` | `192.168.8.21` (app-server) | `SELECT, INSERT, UPDATE, DELETE` sobre `tienda.*` | Conexión desde FastAPI |
| `backup` | `localhost` | `SELECT, LOCK TABLES, PROCESS, RELOAD, SHOW VIEW, TRIGGER` | Ejecución de `mariadb-dump` |

Los privilegios de `tienda_app` excluyen `DROP`, `ALTER`, `CREATE` y
`GRANT` para limitar el impacto de un compromiso de la aplicación.

## Configuración relevante de MariaDB

Vive en `/etc/mysql/mariadb.conf.d/50-server.cnf` (versión completa en
`config/mariadb/50-server.cnf`). Los puntos clave:

- `datadir = /mnt/db-data/mysql`
- `bind-address = 0.0.0.0` (filtrado por UFW para que solo `app-server`
  llegue al puerto 3306).
- `innodb_buffer_pool_size = 256M` (ajustado a 1.5 GB de RAM de la VM).
- AppArmor: ajuste de perfil `/etc/apparmor.d/local/usr.sbin.mysqld` para
  autorizar lectura/escritura sobre el nuevo datadir.

## Por completar tras implementación

- [ ] Salida de `lsblk` mostrando los 4 discos.
- [ ] Salida de `mdadm --detail /dev/md0` con `State: clean`.
- [ ] Salidas de `pvs`, `vgs`, `lvs`.
- [ ] Salida de `df -h /mnt/db-data` y `df -h /mnt/backups`.
- [ ] Salida de `SHOW DATABASES` y `SHOW TABLES FROM tienda`.
- [ ] Captura de conexión exitosa desde `app-server` con `mariadb -h ...`.