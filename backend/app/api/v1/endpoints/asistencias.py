"""Asistencias catalog endpoint — roadside assistance numbers and services."""

import logging
import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.asistencia import Asistencia
from app.schemas.catalogo import AsistenciaCreate, AsistenciaResponse

logger = logging.getLogger("sigad.asistencias")

router = APIRouter(prefix="/asistencias", tags=["Asistencias"])


@router.get("", response_model=List[AsistenciaResponse])
async def listar_asistencias(
    solo_activas: bool = Query(True, description="Mostrar solo asistencias activas"),
    db: AsyncSession = Depends(get_db),
) -> List[AsistenciaResponse]:
    """Obtiene el catálogo de servicios de asistencia en carretera y emergencias."""
    stmt = select(Asistencia)
    if solo_activas:
        stmt = stmt.where(Asistencia.activo.is_(True))

    res = await db.execute(stmt)
    asistencias = res.scalars().all()
    return [AsistenciaResponse.model_validate(a) for a in asistencias]


@router.post("", response_model=AsistenciaResponse, status_code=status.HTTP_201_CREATED)
async def crear_asistencia(
    body: AsistenciaCreate,
    db: AsyncSession = Depends(get_db),
) -> AsistenciaResponse:
    """Registra un nuevo servicio de asistencia."""
    asistencia = Asistencia(
        titulo=body.titulo.strip(),
        descripcion=body.descripcion.strip(),
        telefono_emergencia=body.telefono_emergencia.strip(),
        icono=body.icono.strip(),
        activo=body.activo,
    )
    db.add(asistencia)
    await db.commit()
    await db.refresh(asistencia)
    return AsistenciaResponse.model_validate(asistencia)


@router.get("/{asistencia_id}", response_model=AsistenciaResponse)
async def obtener_asistencia(
    asistencia_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
) -> AsistenciaResponse:
    """Obtiene el detalle de un servicio de asistencia por ID."""
    stmt = select(Asistencia).where(Asistencia.id == asistencia_id)
    res = await db.execute(stmt)
    asistencia = res.scalar_one_or_none()

    if not asistencia:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Servicio de asistencia no encontrado.",
        )

    return AsistenciaResponse.model_validate(asistencia)
