"""Esquemas de póliza dinámicos — Endpoints de administración."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_role
from app.db.session import get_db
from app.models.esquema_poliza import EsquemaPoliza
from app.models.usuario import RolEnum, Usuario
from app.schemas.esquema_poliza import (
    EsquemaPolizaCreate,
    EsquemaPolizaListItem,
    EsquemaPolizaResponse,
)

router = APIRouter(prefix="/esquemas-poliza", tags=["Esquemas de Póliza"])


@router.get("", response_model=list[EsquemaPolizaListItem])
async def listar_esquemas_poliza(
    _: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> list[EsquemaPoliza]:
    """Lista todos los esquemas de póliza (todas las versiones). Solo ADMIN y AGENTE."""
    res = await db.execute(
        select(EsquemaPoliza).order_by(
            EsquemaPoliza.codigo,
            EsquemaPoliza.version.desc(),
        )
    )
    return list(res.scalars().all())


@router.get("/{esquema_id}", response_model=EsquemaPolizaResponse)
async def obtener_esquema_poliza(
    esquema_id: uuid.UUID,
    _: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> EsquemaPoliza:
    """Detalle de un esquema de póliza con sus definiciones de campos."""
    res = await db.execute(
        select(EsquemaPoliza).where(EsquemaPoliza.id == esquema_id)
    )
    esquema = res.scalar_one_or_none()
    if not esquema:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Esquema de póliza no encontrado.",
        )
    return esquema


@router.post("", response_model=EsquemaPolizaResponse, status_code=status.HTTP_201_CREATED)
async def crear_esquema_poliza(
    payload: EsquemaPolizaCreate,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN)),
    db: AsyncSession = Depends(get_db),
) -> EsquemaPoliza:
    """Crea una nueva versión del esquema de póliza (append-only).
    
    - Si el código no existe, crea versión 1.
    - Si ya existe, incrementa la versión. La versión nueva inicia inactiva.
    """
    max_res = await db.execute(
        select(func.max(EsquemaPoliza.version))
        .where(EsquemaPoliza.codigo == payload.codigo)
    )
    nueva_version = (max_res.scalar() or 0) + 1

    esquema = EsquemaPoliza(
        codigo=payload.codigo,
        nombre=payload.nombre,
        descripcion=payload.descripcion,
        version=nueva_version,
        es_activo=False,
        creado_por=current_user.id,
        campos=[c.model_dump() for c in payload.campos],
    )
    db.add(esquema)
    await db.commit()
    await db.refresh(esquema)
    return esquema


@router.patch("/{esquema_id}/activar", response_model=EsquemaPolizaResponse)
async def activar_esquema_poliza(
    esquema_id: uuid.UUID,
    _: Usuario = Depends(check_role(RolEnum.ADMIN)),
    db: AsyncSession = Depends(get_db),
) -> EsquemaPoliza:
    """Activa una versión de esquema de póliza y desactiva las demás del mismo código."""
    res = await db.execute(
        select(EsquemaPoliza).where(EsquemaPoliza.id == esquema_id)
    )
    esquema = res.scalar_one_or_none()
    if not esquema:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Esquema de póliza no encontrado.",
        )

    await db.execute(
        update(EsquemaPoliza)
        .where(
            EsquemaPoliza.codigo == esquema.codigo,
            EsquemaPoliza.id != esquema_id,
        )
        .values(es_activo=False)
    )
    esquema.es_activo = True
    await db.commit()
    await db.refresh(esquema)
    return esquema
