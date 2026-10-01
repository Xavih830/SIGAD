"""Schemas for Documento and OCR extraction lifecycle."""

from datetime import datetime
from typing import Any, Optional
import uuid

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.base import StrictBaseSchema


class DocumentoRevisionRequest(StrictBaseSchema):
    """Payload to review and correct OCR extracted fields."""
    campos_extraidos: dict[str, Any] = Field(
        ...,
        description="Claves y valores extraídos validados por el agente.",
    )
    estado_extraccion: Optional[str] = Field(
        None,
        max_length=30,
        description="Nuevo estado de extracción (completado, requiere_revision_manual).",
    )


class ResultadoExtraccionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    metodo: str
    confianza: float
    texto_completo: Optional[str] = None
    campos_extraidos: dict[str, Any]


class DocumentoResponse(BaseModel):
    """Serialized document representation."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: Optional[uuid.UUID] = None
    nombre_archivo: str
    tipo_mime: str
    tamano_bytes: int
    hash_sha256: Optional[str] = None
    estado_extraccion: str
    intentos: int = 0
    error_motivo: Optional[str] = None
    paginas: Optional[int] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    resultado: Optional[ResultadoExtraccionResponse] = None


class DocumentoRevisionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    estado_extraccion: str
    campos_extraidos: dict[str, Any]
    updated_at: datetime


class DocumentoListItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: Optional[uuid.UUID] = None
    nombre_archivo: str
    tipo_mime: str
    tamano_bytes: int
    estado_extraccion: str
    has_resultado: bool
    created_at: datetime
