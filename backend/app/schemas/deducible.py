"""Pydantic schemas for Deducibles (SC-2026-001)."""

from datetime import datetime
from decimal import Decimal
import uuid

from pydantic import BaseModel, ConfigDict, Field

from app.models.deducible import TipoSiniestroEnum


class DeducibleBase(BaseModel):
    """Atributos base de un deducible diferenciado."""
    tipo_siniestro: TipoSiniestroEnum = Field(
        default=TipoSiniestroEnum.GENERAL,
        description="Tipo de siniestro cubierto (general, robo, choque, perdida_total)",
    )
    porcentaje_valor: Decimal = Field(
        ge=0,
        le=100,
        description="Porcentaje aplicable sobre el valor asegurado",
    )
    monto_minimo_usd: Decimal = Field(
        ge=0,
        description="Monto mínimo en USD a pagar",
    )


class DeducibleCreate(DeducibleBase):
    """Schema para creación de deducible."""
    pass


class DeducibleResponse(DeducibleBase):
    """Schema de respuesta con identificadores y auditoría."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: uuid.UUID
    created_at: datetime
