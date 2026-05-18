from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class Producto(Base):
    __tablename__ = "productos"
    id = Column(Integer, primary_key=True)
    nombre = Column(String(100), nullable=False)
    precio = Column(Float, nullable=False)
    stock = Column(Integer, default=0)

class Pedido(Base):
    __tablename__ = "pedidos"
    id = Column(Integer, primary_key=True)
    cliente = Column(String(100), nullable=False)
    fecha = Column(DateTime, default=datetime.utcnow)
    total = Column(Float, default=0)
    detalles = relationship("DetallePedido", back_populates="pedido")

class DetallePedido(Base):
    __tablename__ = "detalle_pedido"
    id = Column(Integer, primary_key=True)
    pedido_id = Column(Integer, ForeignKey("pedidos.id"))
    producto_id = Column(Integer, ForeignKey("productos.id"))
    cantidad = Column(Integer, nullable=False)
    subtotal = Column(Float, nullable=False)
    pedido = relationship("Pedido", back_populates="detalles")
    producto = relationship("Producto")