from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Pedido, DetallePedido, Producto
import logging

router = APIRouter(prefix="/pedidos", tags=["pedidos"])
logger = logging.getLogger(__name__)

@router.get("/")
def listar(db: Session = Depends(get_db)):
    return db.query(Pedido).all()

@router.post("/")
def crear(cliente: str, producto_id: int, cantidad: int, db: Session = Depends(get_db)):
    producto = db.query(Producto).filter(Producto.id == producto_id).first()
    if not producto:
        logger.error(f"Producto {producto_id} no encontrado")
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    if producto.stock < cantidad:
        logger.error(f"Stock insuficiente para producto {producto_id}")
        raise HTTPException(status_code=400, detail="Stock insuficiente")
    subtotal = producto.precio * cantidad
    pedido = Pedido(cliente=cliente, total=subtotal)
    db.add(pedido)
    db.flush()
    detalle = DetallePedido(
        pedido_id=pedido.id,
        producto_id=producto_id,
        cantidad=cantidad,
        subtotal=subtotal
    )
    db.add(detalle)
    producto.stock -= cantidad
    db.commit()
    logger.info(f"Pedido creado: cliente={cliente}, total={subtotal}")
    return pedido