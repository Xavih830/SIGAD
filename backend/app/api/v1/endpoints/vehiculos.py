"""Endpoints REST para administración de vehículos asociados a pólizas."""

import uuid
from collections.abc import Sequence

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_role, get_current_user
from app.core.constants import DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT
from app.core.exceptions import RecursoNoEncontradoException
from app.db.session import get_db
from app.models.cliente import Cliente
from app.models.usuario import RolEnum, Usuario
from app.models.vehiculo import Vehiculo
from app.schemas.vehiculo import VehiculoCreate, VehiculoResponse, VehiculoUpdate

router = APIRouter(prefix="/vehiculos", tags=["Vehículos"])


@router.post("", response_model=VehiculoResponse, status_code=status.HTTP_201_CREATED)
async def crear_vehiculo(
    payload: VehiculoCreate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Vehiculo:
    """Registrar un nuevo vehículo con validación de placa ANT."""
    if current_user.rol == RolEnum.CLIENTE:
        cliente_res = await db.execute(
            select(Cliente).where(Cliente.id == payload.cliente_id, Cliente.usuario_id == current_user.id)
        )
        if not cliente_res.scalar_one_or_none():
            raise RecursoNoEncontradoException("Recurso no encontrado.")
    else:
        cliente_res = await db.execute(select(Cliente).where(Cliente.id == payload.cliente_id))
        if not cliente_res.scalar_one_or_none():
            raise RecursoNoEncontradoException("Recurso no encontrado.")

    existe_placa = await db.execute(select(Vehiculo).where(Vehiculo.placa == payload.placa))
    if existe_placa.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ya existe un vehículo registrado con la placa {payload.placa}.",
        )

    existe_chasis = await db.execute(select(Vehiculo).where(Vehiculo.chasis == payload.chasis))
    if existe_chasis.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe un vehículo con ese número de chasis.",
        )

    vehiculo = Vehiculo(
        placa=payload.placa,
        marca=payload.marca,
        modelo=payload.modelo,
        anio=payload.anio,
        motor=payload.motor,
        chasis=payload.chasis,
        color=payload.color,
        cliente_id=payload.cliente_id,
    )
    db.add(vehiculo)
    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo


@router.patch(
    "/{id}",
    response_model=VehiculoResponse,
    dependencies=[Depends(check_role([RolEnum.ADMIN, RolEnum.AGENTE]))],
)
async def actualizar_vehiculo(
    id: uuid.UUID,
    payload: VehiculoUpdate,
    db: AsyncSession = Depends(get_db),
) -> Vehiculo:
    """Actualizar parcialmente los datos de un vehículo (excepto placa)."""
    stmt = select(Vehiculo).where(Vehiculo.id == id)
    result = await db.execute(stmt)
    vehiculo = result.scalar_one_or_none()
    if not vehiculo:
        raise RecursoNoEncontradoException("Recurso no encontrado.")

    update_data = payload.model_dump(exclude_unset=True)
    if "chasis" in update_data and update_data["chasis"] != vehiculo.chasis:
        existe_chasis = await db.execute(
            select(Vehiculo).where(Vehiculo.chasis == update_data["chasis"], Vehiculo.id != id)
        )
        if existe_chasis.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ya existe un vehículo con ese número de chasis.",
            )

    for field, value in update_data.items():
        setattr(vehiculo, field, value)

    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo



@router.get("", response_model=list[VehiculoResponse])
async def listar_vehiculos(
    cliente_id: uuid.UUID | None = Query(None, description="Filtrar por ID de cliente."),
    skip: int = Query(0, ge=0, description="Número de registros a omitir."),
    limit: int = Query(
        DEFAULT_PAGE_LIMIT,
        ge=1,
        le=MAX_PAGE_LIMIT,
        description="Límite máximo de registros a retornar.",
    ),
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Sequence[Vehiculo]:
    """Listar vehículos con paginación y filtro opcional por cliente."""
    stmt = select(Vehiculo)
    if current_user.rol == RolEnum.CLIENTE:
        stmt = stmt.join(Cliente, Vehiculo.cliente_id == Cliente.id).where(
            Cliente.usuario_id == current_user.id
        )
        if cliente_id:
            stmt = stmt.where(Vehiculo.cliente_id == cliente_id)
    elif cliente_id:
        stmt = stmt.where(Vehiculo.cliente_id == cliente_id)

    stmt = stmt.order_by(Vehiculo.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{id}", response_model=VehiculoResponse)
async def obtener_vehiculo(
    id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Vehiculo:
    """Obtener detalle de vehículo por ID."""
    stmt = select(Vehiculo).where(Vehiculo.id == id)
    if current_user.rol == RolEnum.CLIENTE:
        stmt = stmt.join(Cliente, Vehiculo.cliente_id == Cliente.id).where(
            Cliente.usuario_id == current_user.id
        )

    result = await db.execute(stmt)
    vehiculo = result.scalar_one_or_none()
    if not vehiculo:
        raise RecursoNoEncontradoException("Recurso no encontrado.")
    return vehiculo
