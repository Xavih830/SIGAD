"""Pydantic schemas para pagos y cuotas de pólizas."""

import uuid
from datetime import date

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.base import StrictBaseSchema


class PagoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: uuid.UUID
    numero_cuota: int
    monto_usd: float
    fecha_vencimiento: date
    fecha_pago: date | None = None
    estado: str
    metodo_pago: str | None = None
    comprobante_ref: str | None = None


class RegistrarPagoRequest(StrictBaseSchema):
    metodo_pago: str = Field(..., min_length=3, max_length=50, description="transferencia, tarjeta, debito_bancario")
    comprobante_ref: str = Field(..., min_length=3, max_length=100)
    fecha_pago: date | None = Field(None, strict=False)
