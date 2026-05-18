from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates
import logging, json
from app.database import engine, Base
from app.routers import productos, pedidos
import app.models

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "event": record.getMessage(),
            "logger": record.name
        }
        return json.dumps(log)

handler = logging.FileHandler("/var/log/tienda/app.log")
handler.setFormatter(JSONFormatter())
logging.getLogger().addHandler(handler)
logging.getLogger().setLevel(logging.INFO)

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Tienda SO-2026")
templates = Jinja2Templates(directory="app/templates")

app.include_router(productos.router)
app.include_router(pedidos.router)

@app.get("/")
def home(request: Request):
    return templates.TemplateResponse(request=request, name="index.html")