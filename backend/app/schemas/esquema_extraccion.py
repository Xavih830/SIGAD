"""Contratos de API para esquemas de extracción. Hereda StrictBaseSchema del proyecto."""

import re
import uuid
from datetime import datetime
from typing import Literal

from pydantic import Field, field_validator, model_validator

from app.core.constants import (
    MAX_CAMPOS_POR_ESQUEMA,
    MAX_DESCRIPCION_ESQUEMA_LENGTH,
    MAX_NOMBRE_CAMPO_LENGTH,
    MAX_REGEX_LENGTH,
)
from app.schemas.base import StrictBaseSchema


class CampoReglaCreate(StrictBaseSchema):
    """Una regla de extracción con validación Fail-Fast de regex y tipo."""

    nombre: str = Field(..., min_length=1, max_length=MAX_NOMBRE_CAMPO_LENGTH)
    regex: str = Field(..., min_length=1, max_length=MAX_REGEX_LENGTH)
    tipo: Literal["texto", "numero", "decimal", "fecha"] = "texto"
    grupo_captura: int = Field(1, ge=1, le=20)
    formato_fecha: str | None = Field(None, max_length=20)
    es_obligatorio: bool = False
    orden: int = Field(0, ge=0, le=999)

    @field_validator("nombre", "regex")
    @classmethod
    def validar_sin_bytes_nulos(cls, v: str) -> str:
        """Anti-Exploit: rechaza caracteres de control nulo (Null-Byte Injection)."""
        if "\x00" in v or "\\x00" in v or "\\0" in v:
            raise ValueError("No se permiten caracteres nulos (\\x00)")
        return v

    @field_validator("regex")
    @classmethod
    def validar_regex_compilable_y_anti_redos(cls, v: str) -> str:
        """Fail-Fast: rechaza regex inválido o potencialmente catastrófico antes de guardar.
        Anti-ReDoS:
        - Limita grupos de captura a 10.
        - Rechaza cuantificadores anidados peligrosos (ej. (a+)+, (.*)*) causantes de backtracking exponencial.
        """
        try:
            re.compile(v, re.IGNORECASE)
        except re.error as exc:
            raise ValueError(f"Patrón regex inválido: {exc}") from exc

        if v.count("(") > 10:
            raise ValueError("Patrón demasiado complejo (máx. 10 grupos de captura)")

        # Detección de cuantificadores anidados: repetición dentro de grupo repetido
        if re.search(r"\([^)]*[+*]\)[+*]", v):
            raise ValueError("Patrón potencialmente catastrófico (repetición anidada detectada - Anti-ReDoS)")

        return v

    @model_validator(mode="after")
    def validar_coherencia_tipo_y_formato(self) -> "CampoReglaCreate":
        """Fail-Fast: coherencia estricta entre tipo y formato_fecha."""
        if self.tipo == "fecha" and not self.formato_fecha:
            raise ValueError(f"Campo '{self.nombre}': formato_fecha es obligatorio cuando tipo='fecha'")
        if self.tipo != "fecha" and self.formato_fecha is not None:
            raise ValueError(f"Campo '{self.nombre}': formato_fecha solo es aplicable cuando tipo='fecha'")
        return self


class EsquemaCreate(StrictBaseSchema):
    """Payload para crear una nueva versión de esquema de extracción."""

    codigo: str = Field(
        ...,
        min_length=1,
        max_length=80,
        pattern=r"^[A-Z0-9_]+$",
        description="Identificador en MAYUSCULAS_GUION_BAJO (ej. EQUINOCCIAL_VEHICULAR)",
    )
    nombre: str = Field(..., min_length=1, max_length=100)
    descripcion: str | None = Field(None, max_length=MAX_DESCRIPCION_ESQUEMA_LENGTH)
    campos: list[CampoReglaCreate] = Field(
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
    def validar_nombres_campos_unicos(cls, v: list[CampoReglaCreate]) -> list[CampoReglaCreate]:
        """Integridad de Dominio: prohíbe campos duplicados en el mismo esquema."""
        nombres = [c.nombre for c in v]
        if len(nombres) != len(set(nombres)):
            duplicados = {n for n in nombres if nombres.count(n) > 1}
            raise ValueError(f"Nombres de campos duplicados en el esquema: {sorted(duplicados)}")
        return v


# ── Responses ─────────────────────────────────────────────────────────────────

class EsquemaListItem(StrictBaseSchema):
    """Item de lista — sin campos para reducir tamaño del payload."""

    id: uuid.UUID
    codigo: str
    nombre: str
    version: int
    es_activo: bool
    created_at: datetime


class EsquemaResponse(StrictBaseSchema):
    """Detalle completo del esquema incluyendo las reglas de campos."""

    id: uuid.UUID
    codigo: str
    nombre: str
    descripcion: str | None
    version: int
    es_activo: bool
    creado_por: uuid.UUID | None
    created_at: datetime
    campos: list[dict]


class ProbarEsquemaResponse(StrictBaseSchema):
    """Resultado de prueba sin persistir."""

    metodo: str
    confianza: float
    campos_extraidos: dict
    texto_completo: str
