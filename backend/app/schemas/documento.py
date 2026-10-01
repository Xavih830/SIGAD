"""Schemas for Documento and OCR extraction lifecycle."""

import uuid
from datetime import datetime
from typing import Any, Optional
from pydantic import BaseModel, ConfigDict, Field


class DocumentoRevisionRequest(BaseModel):
    """Payload to review and correct OCR extracted fields."""
    campos_extraidos: dict[str, Any] = Field(
        ...,
        description="Claves y valores extraídos validados por el agente.",
    )
    estado_extraccion: Optional[str] = Field(
        None,
        description="Nuevo estado de extracción (completado, requiere_revision_manual).",
    )


class DocumentoResponse(BaseModel):
    """Serialized document representation."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    poliza_id: Optional[uuid.UUID] = None
    nombre_archivo: str
    tipo_mime: str
    tamano_bytes: int
    estado_extraccion: str
    intentos: int
    error_motivo: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    resultado: Optional[dict[str, Any]] = None
