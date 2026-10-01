"""Pydantic schemas and ANT license plate validation for Vehiculo."""

import re
from datetime import datetime
import uuid

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.base import StrictBaseSchema

# ANT Ecuador License Plate Formats (Section 11.2):
# 1. Particular & Público: 3 Letters + 4 Digits (e.g. PBA-1234, PTA-1234)
# 2. Moto antigua / estándar: 2 Letters + 4 Digits (e.g. AB-1234)
# 3. Moto alfanumérica ANT actual: 2 Letters + 3 Digits + 1 Letter (e.g. AB-123C)
ANT_PLATE_REGEX = re.compile(r"^(?:[A-Z]{3}-\d{4}|[A-Z]{2}-\d{4}|[A-Z]{2}-\d{3}[A-Z])$")


def validar_placa_ecuador(placa: str) -> bool:
    """Validate Ecuadorian vehicle license plate against official ANT formats (Section 11.2)."""
    if not placa or not isinstance(placa, str):
        return False
    return bool(ANT_PLATE_REGEX.match(placa.strip()))


class VehiculoCreate(StrictBaseSchema):
    """Schema para registrar un nuevo vehículo."""
    placa: str = Field(..., min_length=6, max_length=8)
    marca: str = Field(..., min_length=2, max_length=50)
    modelo: str = Field(..., min_length=2, max_length=50)
    anio: int = Field(..., ge=1900, le=2100)
    cliente_id: uuid.UUID = Field(..., strict=False)

    @field_validator("placa")
    @classmethod
    def validar_placa(cls, value: str) -> str:
        placa_limpia = value.strip()
        if not validar_placa_ecuador(placa_limpia):
            raise ValueError(
                f"Formato de placa inválido ('{value}'). "
                "Debe cumplir formatos ANT: Autos 3L+4D (ej. PBA-1234), "
                "Motos 2L+4D (ej. AB-1234) o Motos ANT 2L+3D+1L (ej. AB-123C)."
            )
        return placa_limpia


class VehiculoResponse(BaseModel):
    """Schema de respuesta de vehículo."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    placa: str
    marca: str
    modelo: str
    anio: int
    cliente_id: uuid.UUID
    created_at: datetime
