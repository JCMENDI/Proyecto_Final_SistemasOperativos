# 04 — Servidor de Base de Datos: RAID-1, LVM y MariaDB

**Responsable:** José  
**VM:** `bdd-server`  
**IP temporal (casa):** 192.168.0.20  
**IP definitiva (switch):** 192.168.8.20  
**OS:** Ubuntu Server 24.04 LTS  

---

## 1. Objetivo

Configurar un servidor de base de datos con alta disponibilidad a nivel de almacenamiento, usando:
- **RAID-1** con `mdadm` para tolerancia a fallos de disco.
- **LVM** sobre el RAID para gestión flexible de volúmenes.
- **MariaDB** con el directorio de datos (`datadir`) en el volumen LVM.

---

## 2. Verificación de discos

Antes de comenzar se verificaron los discos disponibles en la VM:

```bash
lsblk
```

**Resultado:**

| Dispositivo | Tamaño | Uso |
|---|---|---|
| `sda` | 25 GB | Disco del sistema (Ubuntu) |
| `sdb` | 1 GB | Disco para RAID-1 |
| `sdc` | 1 GB | Disco para RAID-1 |
| `sdd` | 1 GB | Disco auxiliar (no usado en el proyecto) |

---

## 3. Configuración de RAID-1

### 3.1 Verificación del estado del RAID

El RAID-1 (`md127`) ya estaba creado sobre `sdb` y `sdc`. Se verificó su estado:

```bash
cat /proc/mdstat
```

**Salida esperada:**
```
md127 : active raid1 sdc[1] sdb[0]
      1046528 blocks super 1.2 [2/2] [UU]
```

El estado `[UU]` indica que ambos discos están activos y sincronizados.

### 3.2 Desmontaje del filesystem directo

El RAID tenía un filesystem ext4 montado directamente en `/mnt/raid1`. Se desmontó para poder crear LVM encima:

```bash
sudo umount /mnt/raid1
sudo wipefs -a /dev/md127
```

---

## 4. Configuración de LVM sobre RAID-1

### 4.1 Crear Physical Volume

```bash
sudo pvcreate /dev/md127
```

**Salida esperada:**
```
Physical volume "/dev/md127" successfully created.
```

### 4.2 Crear Volume Group

```bash
sudo vgcreate vg-db /dev/md127
```

**Salida esperada:**
```
Volume group "vg-db" successfully created
```

### 4.3 Crear Logical Volume

```bash
sudo lvcreate -n db-data -l 100%FREE vg-db
```

**Salida esperada:**
```
Logical volume "db-data" created.
```

### 4.4 Formatear y montar

```bash
sudo mkfs.ext4 /dev/vg-db/db-data
sudo mkdir -p /mnt/db-data
sudo mount /dev/vg-db/db-data /mnt/db-data
```

### 4.5 Persistencia en fstab

Se obtuvo el UUID del volumen:

```bash
sudo blkid /dev/vg-db/db-data
```

Se agregó la entrada al `/etc/fstab`:

```bash
echo 'UUID=05b957f9-91a9-4cb3-baab-a6bdfcae4ff0 /mnt/db-data ext4 defaults 0 2' | sudo tee -a /etc/fstab
```

Se removieron entradas antiguas de `/mnt/raid1` y `/mnt/vol1`:

```bash
sudo sed -i '/mnt\/raid1/d' /etc/fstab
sudo sed -i '/mnt\/vol1/d' /etc/fstab
sudo mount -a
```

### 4.6 Verificación final de almacenamiento

```bash
lsblk
df -h /mnt/db-data
```

**Resultado:**
```
/dev/mapper/vg--db--db-data   986M   24K  919M   1%  /mnt/db-data
```

---

## 5. Instalación y configuración de MariaDB

### 5.1 Instalación

MariaDB 10.11 ya estaba instalada en la VM. Se verificó:

```bash
sudo systemctl status mariadb --no-pager
```

### 5.2 Mover el datadir al volumen LVM

Se detuvo MariaDB y se copiaron los datos al nuevo destino:

```bash
sudo systemctl stop mariadb
sudo mkdir -p /mnt/db-data/mysql
sudo rsync -av /var/lib/mysql/ /mnt/db-data/mysql/
sudo chown -R mysql:mysql /mnt/db-data/mysql
```

Se actualizó la configuración en `/etc/mysql/mariadb.conf.d/50-server.cnf`:

```ini
datadir = /mnt/db-data/mysql
bind-address = 0.0.0.0
```

Se reinició MariaDB:

```bash
sudo systemctl start mariadb
sudo systemctl status mariadb --no-pager
```

**Verificación en logs:**
```
InnoDB: Loading buffer pool(s) from /mnt/db-data/mysql/ib_buffer_pool
```

### 5.3 Asegurar la instalación

```bash
sudo mysql_secure_installation
```

Opciones aplicadas:
- No cambiar autenticación unix_socket
- No cambiar contraseña root
- Eliminar usuarios anónimos ✓
- Deshabilitar login root remoto ✓
- Eliminar base de datos `test` ✓
- Recargar tabla de privilegios ✓

---

## 6. Creación de base de datos y usuarios

```sql
CREATE DATABASE tienda CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER 'tienda_app'@'192.168.8.21' IDENTIFIED BY 'tienda_pass_2026';
GRANT ALL PRIVILEGES ON tienda.* TO 'tienda_app'@'192.168.8.21';

CREATE USER 'backup'@'localhost' IDENTIFIED BY 'backup_pass_2026';
GRANT SELECT, LOCK TABLES ON tienda.* TO 'backup'@'localhost';

FLUSH PRIVILEGES;
```

**Verificación:**

```sql
SHOW DATABASES;
SELECT User, Host FROM mysql.user;
```

| User | Host |
|---|---|
| `tienda_app` | `192.168.8.21` |
| `backup` | `localhost` |
| `root` | `localhost` |

---

## 7. Configuración de UFW

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow from 192.168.8.21 to any port 3306
sudo ufw enable
```

**Reglas activas:**

| Puerto | Acción | Desde |
|---|---|---|
| 22/tcp | ALLOW | Anywhere |
| 3306 | ALLOW | 192.168.8.21 |

---

## 8. Verificación final

```bash
sudo systemctl status mariadb --no-pager
sudo ufw status verbose
lsblk
cat /proc/mdstat
sudo pvs && sudo vgs && sudo lvs
```