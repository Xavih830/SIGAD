"""Pydantic schemas para pagos y cuotas de pólizas."""

from datetime import date
from typing import Optional
import uuid

from pydantic import BaseModel, ConfigDict, Field


from app.schemas.base import StrictBaseSchema


class PagoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: uuid.UUID
    numero_cuota: int
    monto_usd: float
    fecha_vencimiento: date
    fecha_pago: Optional[date] = None
    estado: str
    metodo_pago: Optional[str] = None
    comprobante_ref: Optional[str] = None


class RegistrarPagoRequest(StrictBaseSchema):
    metodo_pago: str = Field(..., min_length=3, max_length=50, description="transferencia, tarjeta, debito_bancario")
    comprobante_ref: str = Field(..., min_length=3, max_length=100)
    fecha_pago: Optional[date] = Field(None, strict=False)
