"""Contratos de API para esquemas de póliza dinámicos. Hereda StrictBaseSchema."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import Field, field_validator, model_validator

from app.core.constants import (
    MAX_CAMPOS_POR_ESQUEMA,
    MAX_DESCRIPCION_ESQUEMA_LENGTH,
    MAX_NOMBRE_CAMPO_LENGTH,
)
from app.schemas.base import StrictBaseSchema


class CampoPolizaDefinicion(StrictBaseSchema):
    """Definición declarativa de un campo para esquema de póliza."""

    nombre: str = Field(..., min_length=1, max_length=MAX_NOMBRE_CAMPO_LENGTH)
    tipo: Literal["texto", "numero", "decimal", "fecha", "booleano"] = "texto"
    es_obligatorio: bool = False
    orden: int = Field(0, ge=0, le=999)
    formato_fecha: str | None = Field(None, max_length=20)

    @field_validator("nombre")
    @classmethod
    def validar_sin_bytes_nulos(cls, v: str) -> str:
        if "\x00" in v or "\\x00" in v or "\\0" in v:
            raise ValueError("No se permiten caracteres nulos (\\x00)")
        return v

    @model_validator(mode="after")
    def validar_coherencia_tipo_y_formato(self) -> "CampoPolizaDefinicion":
        if self.tipo == "fecha" and not self.formato_fecha:
            raise ValueError(f"Campo '{self.nombre}': formato_fecha es obligatorio cuando tipo='fecha'")
        if self.tipo != "fecha" and self.formato_fecha is not None:
            raise ValueError(f"Campo '{self.nombre}': formato_fecha solo es aplicable cuando tipo='fecha'")
        return self


class EsquemaPolizaCreate(StrictBaseSchema):
    """Payload para crear una nueva versión de esquema de póliza."""

    codigo: str = Field(
        ...,
        min_length=1,
        max_length=80,
        pattern=r"^[A-Z0-9_]+$",
        description="Identificador en MAYUSCULAS_GUION_BAJO (ej. VEHICULAR_PESADOS)",
    )
    nombre: str = Field(..., min_length=1, max_length=100)
    descripcion: str | None = Field(None, max_length=MAX_DESCRIPCION_ESQUEMA_LENGTH)
    campos: list[CampoPolizaDefinicion] = Field(
        ...,
        min_length=1,
        max_length=MAX_CAMPOS_POR_ESQUEMA,
    )

    @field_validator("codigo", "nombre")
    @classmethod
    def validar_texto_sin_bytes_nulos(cls, v: str) -> str:
        if "\x00" in v or "\\x00" in v or "\\0" in v:
            raise ValueError("No se permiten caracteres nulos (\\x00)")
        return v

    @field_validator("campos")
    @classmethod
    def validar_nombres_campos_unicos(cls, v: list[CampoPolizaDefinicion]) -> list[CampoPolizaDefinicion]:
        nombres = [c.nombre for c in v]
        if len(nombres) != len(set(nombres)):
            duplicados = {n for n in nombres if nombres.count(n) > 1}
            raise ValueError(f"Nombres de campos duplicados en el esquema: {sorted(duplicados)}")
        return v


class EsquemaPolizaListItem(StrictBaseSchema):
    """Item de lista ligera para esquemas de póliza."""

    id: uuid.UUID
    codigo: str
    nombre: str
    version: int
    es_activo: bool
    created_at: datetime


class EsquemaPolizaResponse(StrictBaseSchema):
    """Detalle completo del esquema de póliza incluyendo sus campos."""

    id: uuid.UUID
    codigo: str
    nombre: str
    descripcion: str | None
    version: int
    es_activo: bool
    creado_por: uuid.UUID | None
    created_at: datetime
    campos: list[CampoPolizaDefinicion]
