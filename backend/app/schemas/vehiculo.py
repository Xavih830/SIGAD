"""Pydantic schemas and ANT license plate validation for Vehiculo."""

import re
import uuid
from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, computed_field, field_validator

from app.schemas.base import StrictBaseSchema

ANT_PLATE_REGEX = re.compile(r"^(?:[A-Z]{3}-\d{4}|[A-Z]{2}-\d{4}|[A-Z]{2}-\d{3}[A-Z])$")
MOTOR_REGEX = re.compile(r"^[A-Z0-9-]{5,30}$")
CHASIS_REGEX = re.compile(r"^[A-HJ-NPR-Z0-9]{17}$")
COLOR_REGEX = re.compile(r"^[A-ZÁÉÍÓÚÑÜ\s]{3,30}$")


class TipoPlacaEnum(StrEnum):
    PARTICULAR = "PARTICULAR"
    MOTO = "MOTO"
    SERVICIO_PUBLICO = "SERVICIO_PUBLICO"
    GUBERNAMENTAL = "GUBERNAMENTAL"


def validar_placa_ecuador(placa: str) -> bool:
    """Valida placas vehiculares de Ecuador conforme a los formatos oficiales de la ANT."""
    if not placa or not isinstance(placa, str):
        return False
    return bool(ANT_PLATE_REGEX.match(placa.strip()))


def clasificar_placa(placa: str) -> TipoPlacaEnum | None:
    """Clasifica una placa ecuatoriana ANT según la regla de la segunda letra (Decisión D5)."""
    if not validar_placa_ecuador(placa):
        return None
    p = placa.strip().upper()
    letras = p.split("-")[0]
    if len(letras) == 2:
        return TipoPlacaEnum.MOTO
    if len(letras) == 3:
        segunda_letra = letras[1]
        if segunda_letra in ("A", "U", "Z"):
            return TipoPlacaEnum.SERVICIO_PUBLICO
        if segunda_letra in ("E", "X", "M", "S"):
            return TipoPlacaEnum.GUBERNAMENTAL
        return TipoPlacaEnum.PARTICULAR
    return None


def validar_motor(motor: str) -> str:
    """Normaliza y valida el número de motor."""
    limpio = motor.strip().upper()
    if not MOTOR_REGEX.match(limpio):
        raise ValueError(
            f"Número de motor inválido ('{motor}'). "
            "Debe tener entre 5 y 30 caracteres alfanuméricos o guiones."
        )
    return limpio


def validar_chasis(chasis: str) -> str:
    """Normaliza y valida el número de chasis (VIN de 17 caracteres excluyendo I, O, Q)."""
    limpio = chasis.strip().upper()
    if not CHASIS_REGEX.match(limpio):
        raise ValueError(
            f"Número de chasis inválido ('{chasis}'). "
            "Debe cumplir estándar VIN de 17 caracteres alfanuméricos (excluyendo I, O, Q)."
        )
    return limpio


def validar_color(color: str) -> str:
    """Normaliza y valida el color del vehículo."""
    limpio = color.strip().upper()
    if not COLOR_REGEX.match(limpio):
        raise ValueError(
            f"Color inválido ('{color}'). "
            "Debe tener entre 3 y 30 caracteres alfabéticos (se permiten tildes y espacios)."
        )
    return limpio


class VehiculoCreate(StrictBaseSchema):
    """Schema para registrar un nuevo vehículo."""
    placa: str = Field(..., min_length=6, max_length=8)
    marca: str = Field(..., min_length=2, max_length=50)
    modelo: str = Field(..., min_length=2, max_length=50)
    anio: int = Field(..., ge=1900, le=2100)
    motor: str = Field(..., min_length=5, max_length=30)
    chasis: str = Field(..., min_length=17, max_length=17)
    color: str = Field(..., min_length=3, max_length=30)
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

    @field_validator("motor")
    @classmethod
    def validar_motor_field(cls, value: str) -> str:
        return validar_motor(value)

    @field_validator("chasis")
    @classmethod
    def validar_chasis_field(cls, value: str) -> str:
        return validar_chasis(value)

    @field_validator("color")
    @classmethod
    def validar_color_field(cls, value: str) -> str:
        return validar_color(value)


class VehiculoUpdate(StrictBaseSchema):
    """Schema para actualizar parcialmente un vehículo (la placa no se edita)."""
    marca: str | None = Field(None, min_length=2, max_length=50)
    modelo: str | None = Field(None, min_length=2, max_length=50)
    anio: int | None = Field(None, ge=1900, le=2100)
    motor: str | None = Field(None, min_length=5, max_length=30)
    chasis: str | None = Field(None, min_length=17, max_length=17)
    color: str | None = Field(None, min_length=3, max_length=30)

    @field_validator("motor")
    @classmethod
    def validar_motor_update(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validar_motor(value)

    @field_validator("chasis")
    @classmethod
    def validar_chasis_update(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validar_chasis(value)

    @field_validator("color")
    @classmethod
    def validar_color_update(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validar_color(value)


class VehiculoResponse(BaseModel):
    """Schema de respuesta de vehículo."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    placa: str
    marca: str
    modelo: str
    anio: int
    motor: str | None = None
    chasis: str | None = None
    color: str | None = None
    cliente_id: uuid.UUID
    created_at: datetime

    @computed_field
    @property
    def tipo_placa(self) -> TipoPlacaEnum:
        tipo = clasificar_placa(self.placa)
        return tipo or TipoPlacaEnum.PARTICULAR


