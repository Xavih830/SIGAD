"""Vehiculos REST endpoints with SQL-level Anti-BOLA guards."""

import uuid
from typing import Sequence

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_role, get_current_user
from app.db.session import get_db
from app.models.cliente import Cliente
from app.models.usuario import RolEnum, Usuario
from app.models.vehiculo import Vehiculo
from app.schemas.vehiculo import VehiculoCreate, VehiculoResponse

router = APIRouter(prefix="/vehiculos", tags=["Vehículos"])


@router.post("", response_model=VehiculoResponse, status_code=status.HTTP_201_CREATED)
async def crear_vehiculo(
    payload: VehiculoCreate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Vehiculo:
    """Registrar un nuevo vehículo con validación de placa ANT.
    
    Anti-BOLA: Clientes solo pueden registrar vehículos asociados a su propia ficha de cliente.
    """
    if current_user.rol == RolEnum.CLIENTE:
        # Validar que el cliente_id pertenezca al usuario autenticado
        cliente_res = await db.execute(
            select(Cliente).where(Cliente.id == payload.cliente_id, Cliente.usuario_id == current_user.id)
        )
        if not cliente_res.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No está autorizado para registrar un vehículo para este cliente.",
            )
    else:
        # Validar que el cliente exista en la base de datos
        cliente_res = await db.execute(select(Cliente).where(Cliente.id == payload.cliente_id))
        if not cliente_res.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Cliente con ID {payload.cliente_id} no existe.",
            )

    # Verificar unicidad de placa
    existe = await db.execute(select(Vehiculo).where(Vehiculo.placa == payload.placa))
    if existe.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya existe un vehículo registrado con la placa {payload.placa}.",
        )

    vehiculo = Vehiculo(
        placa=payload.placa,
        marca=payload.marca,
        modelo=payload.modelo,
        anio=payload.anio,
        cliente_id=payload.cliente_id,
    )
    db.add(vehiculo)
    await db.commit()
    await db.refresh(vehiculo)
    return vehiculo


@router.get("", response_model=list[VehiculoResponse])
async def listar_vehiculos(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Sequence[Vehiculo]:
    """Listar vehículos.
    
    Anti-BOLA estricto a nivel de consulta SQL:
    Los usuarios con rol 'cliente' solo ven sus propios vehículos registrados.
    """
    stmt = select(Vehiculo)
    if current_user.rol == RolEnum.CLIENTE:
        stmt = stmt.join(Cliente, Vehiculo.cliente_id == Cliente.id).where(
            Cliente.usuario_id == current_user.id
        )

    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{id}", response_model=VehiculoResponse)
async def obtener_vehiculo(
    id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Vehiculo:
    """Obtener detalle de vehículo por ID con protección Anti-BOLA."""
    stmt = select(Vehiculo).where(Vehiculo.id == id)
    if current_user.rol == RolEnum.CLIENTE:
        stmt = stmt.join(Cliente, Vehiculo.cliente_id == Cliente.id).where(
            Cliente.usuario_id == current_user.id
        )

    result = await db.execute(stmt)
    vehiculo = result.scalar_one_or_none()
    if not vehiculo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado.",
        )
    return vehiculo
