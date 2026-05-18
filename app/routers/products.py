from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Producto
import logging

router = APIRouter(prefix="/productos", tags=["productos"])
logger = logging.getLogger(__name__)

@router.get("/")
def listar(db: Session = Depends(get_db)):
    logger.info("Listando productos")
    return db.query(Producto).all()

@router.post("/")
def crear(nombre: str, precio: float, stock: int, db: Session = Depends(get_db)):
    p = Producto(nombre=nombre, precio=precio, stock=stock)
    db.add(p)
    db.commit()
    logger.info(f"Producto creado: {nombre}")
    return p