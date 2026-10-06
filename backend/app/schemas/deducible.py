"""Pydantic schemas for Deducibles (SC-2026-001)."""

from datetime import datetime
from decimal import Decimal
import uuid

from pydantic import BaseModel, ConfigDict, Field

from app.models.deducible import TipoSiniestroEnum


from app.schemas.base import StrictBaseSchema


class DeducibleCreate(StrictBaseSchema):
    """Schema para creación de deducible."""
    tipo_siniestro: TipoSiniestroEnum = Field(
        default=TipoSiniestroEnum.GENERAL,
        strict=False,
        description="Tipo de siniestro cubierto (general, robo, choque, perdida_total)",
    )
    porcentaje_valor: Decimal = Field(
        ge=0,
        le=100,
        strict=False,
        description="Porcentaje aplicable sobre el valor asegurado",
    )
    monto_minimo_usd: Decimal = Field(
        ge=0,
        strict=False,
        description="Monto mínimo en USD a pagar",
    )


class DeducibleResponse(BaseModel):
    """Schema de respuesta con identificadores y auditoría."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: uuid.UUID
    tipo_siniestro: TipoSiniestroEnum
    porcentaje_valor: Decimal
    monto_minimo_usd: Decimal
    created_at: datetime
