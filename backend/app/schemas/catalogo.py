"""Pydantic schemas for relational catalogs: Talleres and Asistencias."""

import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class TallerCreate(BaseModel):
    """Schema para registrar un nuevo taller mecánico autorizado."""

    nombre: str = Field(..., min_length=2, max_length=255)
    direccion: str = Field(..., min_length=5, max_length=255)
    telefono: str = Field(..., min_length=5, max_length=50)
    ciudad: str = Field(..., min_length=2, max_length=100)
    activo: bool = True


class TallerResponse(BaseModel):
    """Schema de respuesta para taller mecánico."""

    id: uuid.UUID
    nombre: str
    direccion: str
    telefono: str
    ciudad: str
    activo: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AsistenciaCreate(BaseModel):
    """Schema para registrar un nuevo servicio de asistencia."""

    titulo: str = Field(..., min_length=2, max_length=255)
    descripcion: str = Field(..., min_length=5)
    telefono_emergencia: str = Field(..., min_length=3, max_length=50)
    icono: str = Field(default="phone", max_length=100)
    activo: bool = True


class AsistenciaResponse(BaseModel):
    """Schema de respuesta para servicio de asistencia."""

    id: uuid.UUID
    titulo: str
    descripcion: str
    telefono_emergencia: str
    icono: str
    activo: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
