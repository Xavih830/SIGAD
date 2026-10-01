"""Pydantic schemas for Poliza lifecycle, creation and responses."""

from datetime import date, datetime
from decimal import Decimal
import uuid

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.domain.poliza_evaluator import (
    EstadoPoliza,
    validar_limite_vigencia_maxima,
    validar_y_calcular_estado_inicial,
)
from app.schemas.base import StrictBaseSchema
from app.schemas.deducible import DeducibleCreate, DeducibleResponse


class CoberturaBase(BaseModel):
    """Cobertura asegurada dentro de una póliza."""
    nombre: str
    monto: Decimal = Field(gt=0, description="Monto asegurado para la cobertura")


class CoberturaCreate(StrictBaseSchema):
    nombre: str = Field(..., min_length=2, max_length=100)
    monto: Decimal = Field(..., gt=0, strict=False, description="Monto asegurado para la cobertura")


class CoberturaResponse(CoberturaBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: uuid.UUID
    created_at: datetime


class PolizaCreate(StrictBaseSchema):
    """Schema para emisión de una nueva póliza.
    
    Exige snapshot inmutable de kilometraje_emision y valida vigencia.
    """
    numero_poliza: str = Field(min_length=3, max_length=50)
    cliente_id: uuid.UUID = Field(..., strict=False)
    vehiculo_id: uuid.UUID = Field(..., strict=False)
    inspeccion_id: uuid.UUID | None = Field(None, strict=False)
    fecha_inicio: date = Field(..., strict=False)
    fecha_fin: date = Field(..., strict=False)
    valor_asegurado: Decimal = Field(gt=0, strict=False, description="Valor comercial asegurado")
    prima_mensual: Decimal = Field(gt=0, strict=False, description="Prima mensual calculada")
    kilometraje_emision: int = Field(ge=0, description="Snapshot contractual inmutable al emitir")
    deducibles: list[DeducibleCreate] | None = None
    coberturas: list[CoberturaCreate] | None = None

    @model_validator(mode="after")
    def validar_fechas_y_vigencia(self) -> "PolizaCreate":
        # 1. Coherencia cronológica (Nodo 4: FechaInvalidaException si fin <= inicio)
        validar_y_calcular_estado_inicial(self.fecha_inicio, self.fecha_fin, date.today())
        
        # 2. Límite máximo de 5 años (Sección 11.3 -> 422 VigenciaExcedidaException)
        validar_limite_vigencia_maxima(self.fecha_inicio, self.fecha_fin)
        return self


class PolizaUpdateEstado(StrictBaseSchema):
    """Schema para transición de estado de póliza."""
    estado: EstadoPoliza = Field(..., strict=False)


class PolizaResponse(BaseModel):
    """Schema de respuesta completo para una póliza."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    numero_poliza: str
    cliente_id: uuid.UUID
    vehiculo_id: uuid.UUID
    inspeccion_id: uuid.UUID | None
    fecha_inicio: date
    fecha_fin: date
    estado: EstadoPoliza
    valor_asegurado: Decimal
    prima_mensual: Decimal
    kilometraje_emision: int
    created_at: datetime
    updated_at: datetime
    deducibles: list[DeducibleResponse] = []
    coberturas: list[CoberturaResponse] = []
