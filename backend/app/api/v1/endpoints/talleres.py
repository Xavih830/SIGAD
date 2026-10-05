"""Talleres catalog endpoint — authorized workshops query and creation."""

import logging
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_catalog_rate_limit, check_role
from app.db.session import get_db
from app.models.taller import Taller
from app.models.usuario import RolEnum, Usuario
from app.schemas.catalogo import TallerCreate, TallerResponse

logger = logging.getLogger("sigad.talleres")

router = APIRouter(prefix="/talleres", tags=["Talleres"])


@router.get("", response_model=List[TallerResponse])
async def listar_talleres(
    response: Response,
    ciudad: Optional[str] = Query(None, description="Filtrar por ciudad"),
    solo_activos: bool = Query(True, description="Mostrar solo talleres activos"),
    _: None = Depends(check_catalog_rate_limit),
    db: AsyncSession = Depends(get_db),
) -> List[TallerResponse]:
    """Obtiene el catálogo de talleres autorizados."""
    response.headers["Cache-Control"] = "public, max-age=300"
    stmt = select(Taller)
    if solo_activos:
        stmt = stmt.where(Taller.activo.is_(True))
    if ciudad:
        stmt = stmt.where(Taller.ciudad.ilike(f"%{ciudad.strip()}%"))

    res = await db.execute(stmt)
    talleres = res.scalars().all()
    return [TallerResponse.model_validate(t) for t in talleres]


@router.post("", response_model=TallerResponse, status_code=status.HTTP_201_CREATED)
async def crear_taller(
    body: TallerCreate,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN)),
    db: AsyncSession = Depends(get_db),
) -> TallerResponse:
    """Registra un nuevo taller autorizado."""
    taller = Taller(
        nombre=body.nombre.strip(),
        direccion=body.direccion.strip(),
        telefono=body.telefono.strip(),
        ciudad=body.ciudad.strip(),
        activo=body.activo,
    )
    db.add(taller)
    await db.commit()
    await db.refresh(taller)
    return TallerResponse.model_validate(taller)


@router.get("/{taller_id}", response_model=TallerResponse)
async def obtener_taller(
    taller_id: uuid.UUID,
    response: Response,
    _: None = Depends(check_catalog_rate_limit),
    db: AsyncSession = Depends(get_db),
) -> TallerResponse:
    """Obtiene un taller por su ID."""
    response.headers["Cache-Control"] = "public, max-age=300"
    stmt = select(Taller).where(Taller.id == taller_id)
    res = await db.execute(stmt)
    taller = res.scalar_one_or_none()

    if not taller:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Taller no encontrado.",
        )

    return TallerResponse.model_validate(taller)
