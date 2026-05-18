# 07 — Servidor de Aplicación: FastAPI + Filebeat

**Responsable:** José  
**VM:** `app-server`  
**IP temporal (casa):** 192.168.0.21  
**IP definitiva (switch):** 192.168.8.21  
**OS:** Ubuntu Server 24.04 LTS  

---

## 1. Objetivo

Configurar el servidor de aplicación con:
- **FastAPI** como framework web para la tienda en línea.
- **SQLAlchemy + PyMySQL** para la conexión a MariaDB.
- **Systemd** para gestionar el servicio de la aplicación.
- **Filebeat** configurado para enviar logs al elk-server (activo en Fase 2).

---

## 2. Configuración de red

IP estática configurada en `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses:
        - 192.168.0.21/24
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
      routes:
        - to: default
          via: 192.168.0.1
```

```bash
sudo netplan apply
```

> **Nota:** Al conectar el switch, cambiar a `192.168.8.21/24` con gateway `192.168.8.1`.

---

## 3. Instalación de dependencias

```bash
sudo apt update && sudo apt install -y python3-pip python3-venv git
```

---

## 4. Estructura de directorios

```bash
sudo mkdir -p /opt/tienda
sudo mkdir -p /var/log/tienda
sudo chown -R urlos:urlos /opt/tienda
sudo chown -R urlos:urlos /var/log/tienda
```

**Estructura del proyecto:**

```
/opt/tienda/
├── venv/                   # Entorno virtual Python
└── app/
    ├── __init__.py
    ├── main.py             # Entry point FastAPI
    ├── database.py         # Conexión SQLAlchemy
    ├── models.py           # Modelos ORM
    ├── routers/
    │   ├── __init__.py
    │   ├── productos.py    # CRUD productos
    │   └── pedidos.py      # CRUD pedidos
    └── templates/
        └── index.html      # Página principal
```

---

## 5. Entorno virtual e instalación de librerías

```bash
cd /opt/tienda
python3 -m venv venv
source venv/bin/activate
pip install fastapi uvicorn sqlalchemy pymysql jinja2 python-multipart
deactivate
```

**Librerías instaladas:**

| Librería | Propósito |
|---|---|
| `fastapi` | Framework web |
| `uvicorn` | Servidor ASGI |
| `sqlalchemy` | ORM para base de datos |
| `pymysql` | Driver MySQL/MariaDB |
| `jinja2` | Templates HTML |
| `python-multipart` | Formularios |

---

## 6. Código de la aplicación

### 6.1 `app/database.py` — Conexión a MariaDB

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

DB_URL = "mysql+pymysql://tienda_app:tienda_pass_2026@192.168.8.20/tienda"

engine = create_engine(DB_URL)
SessionLocal = sessionmaker(bind=engine)

class Base(DeclarativeBase):
    pass

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### 6.2 `app/models.py` — Modelos de datos

Tablas creadas:

| Tabla | Descripción |
|---|---|
| `productos` | Catálogo de productos con nombre, precio y stock |
| `pedidos` | Encabezado de pedido con cliente y total |
| `detalle_pedido` | Líneas de pedido con producto, cantidad y subtotal |

### 6.3 `app/main.py` — Configuración principal

- Logging en formato JSON a `/var/log/tienda/app.log`
- Creación automática de tablas al iniciar (`Base.metadata.create_all`)
- Rutas registradas: `/productos/` y `/pedidos/`

### 6.4 Endpoints disponibles

| Método | Endpoint | Descripción |
|---|---|---|
| GET | `/` | Página principal |
| GET | `/docs` | Documentación automática (Swagger) |
| GET | `/productos/` | Listar productos |
| POST | `/productos/` | Crear producto |
| GET | `/pedidos/` | Listar pedidos |
| POST | `/pedidos/` | Crear pedido |

---

## 7. Servicio systemd

Se creó `/etc/systemd/system/tienda.service`:

```ini
[Unit]
Description=Tienda SO-2026 FastAPI
After=network.target

[Service]
User=urlos
WorkingDirectory=/opt/tienda
ExecStart=/opt/tienda/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=3
StandardOutput=append:/var/log/tienda/app.log
StandardError=append:/var/log/tienda/app.log

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable tienda
sudo systemctl start tienda
```

**Verificación:**

```bash
sudo systemctl status tienda --no-pager
curl http://localhost:8000/productos/
```

---

## 8. Configuración de UFW

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 8000/tcp
sudo ufw enable
```

---

## 9. Instalación y configuración de Filebeat

### 9.1 Instalación

```bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt update && sudo apt install -y filebeat
```

### 9.2 Configuración `/etc/filebeat/filebeat.yml`

```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/tienda/app.log
    json.keys_under_root: true
    json.add_error_key: true
    tags: ["tienda", "app-server"]

output.logstash:
  hosts: ["192.168.8.22:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
```

### 9.3 Estado del servicio

Filebeat está instalado y configurado pero **desactivado** hasta que el switch esté disponible:

```bash
sudo systemctl status filebeat --no-pager
# Active: inactive (dead)
# Loaded: disabled
```

**Para activar en Fase 2 (con switch):**

```bash
sudo systemctl enable filebeat
sudo systemctl start filebeat
```

---

## 10. Prueba end-to-end

```bash
# Crear productos
curl -X POST "http://localhost:8000/productos/?nombre=Laptop&precio=5999.99&stock=10"
curl -X POST "http://localhost:8000/productos/?nombre=Mouse&precio=199.99&stock=50"

# Verificar
curl http://localhost:8000/productos/
```

**Respuesta esperada:**
```json
[
  {"precio": 5999.99, "stock": 10, "id": 1, "nombre": "Laptop"},
  {"precio": 199.99, "stock": 50, "id": 2, "nombre": "Mouse"}
]
```