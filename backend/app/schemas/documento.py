"""Schemas for Documento and OCR extraction lifecycle."""

from datetime import datetime
import uuid

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.base import StrictBaseSchema

ValorCampoOCR = str | int | float | bool | None


class DocumentoRevisionRequest(StrictBaseSchema):
    """Payload to review and correct OCR extracted fields."""
    campos_extraidos: dict[str, ValorCampoOCR] = Field(
        ...,
        description="Claves y valores extraídos validados por el agente.",
    )
    estado_extraccion: str | None = Field(
        None,
        max_length=30,
        description="Nuevo estado de extracción (completado, requiere_revision_manual).",
    )


class ResultadoExtraccionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    metodo: str
    confianza: float
    texto_completo: str | None = None
    campos_extraidos: dict[str, ValorCampoOCR]


class DocumentoResponse(BaseModel):
    """Serialized document representation."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: uuid.UUID | None = None
    nombre_archivo: str
    tipo_mime: str
    tamano_bytes: int
    hash_sha256: str | None = None
    estado_extraccion: str
    intentos: int = 0
    error_motivo: str | None = None
    paginas: int | None = None
    created_at: datetime
    updated_at: datetime | None = None
    resultado: ResultadoExtraccionResponse | None = None


class DocumentoRevisionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    estado_extraccion: str
    campos_extraidos: dict[str, ValorCampoOCR]
    updated_at: datetime


class DocumentoListItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: uuid.UUID | None = None
    nombre_archivo: str
    tipo_mime: str
    tamano_bytes: int
    estado_extraccion: str
    has_resultado: bool
    created_at: datetime
