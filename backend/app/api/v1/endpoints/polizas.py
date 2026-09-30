"""Polizas REST endpoints with SQL-level Anti-BOLA guards and SC-2026-001 support."""

from datetime import date
from decimal import Decimal
from typing import Sequence
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import check_role, get_current_user
from app.db.session import get_db
from app.domain.poliza_evaluator import (
    validar_limite_vigencia_maxima,
    validar_y_calcular_estado_inicial,
)
from app.models.cliente import Cliente
from app.models.cobertura import Cobertura
from app.models.deducible import Deducible, TipoSiniestroEnum
from app.models.poliza import Poliza
from app.models.usuario import RolEnum, Usuario
from app.models.vehiculo import Vehiculo
from app.schemas.deducible import DeducibleResponse
from app.schemas.poliza import (
    PolizaCreate,
    PolizaResponse,
    PolizaUpdateEstado,
)

router = APIRouter(prefix="/polizas", tags=["Pólizas"])


@router.post("", response_model=PolizaResponse, status_code=status.HTTP_201_CREATED)
async def crear_poliza(
    payload: PolizaCreate,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> Poliza:
    """Emisión formal de póliza con snapshot inmutable de kilometraje y evaluación de CFG."""
    # 1. Verificar existencia del cliente y vehículo
    cliente_res = await db.execute(select(Cliente).where(Cliente.id == payload.cliente_id))
    cliente = cliente_res.scalar_one_or_none()
    if not cliente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cliente con ID {payload.cliente_id} no existe.",
        )

    vehiculo_res = await db.execute(select(Vehiculo).where(Vehiculo.id == payload.vehiculo_id))
    vehiculo = vehiculo_res.scalar_one_or_none()
    if not vehiculo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Vehículo con ID {payload.vehiculo_id} no existe.",
        )

    # 2. Verificar unicidad de número de póliza
    poliza_existente = await db.execute(
        select(Poliza).where(Poliza.numero_poliza == payload.numero_poliza)
    )
    if poliza_existente.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya existe una póliza con número {payload.numero_poliza}.",
        )

    # 3. Dominio: cálculo de estado inicial formal (CFG 10 nodos, V(G)=4)
    hoy = date.today()
    estado_inicial = validar_y_calcular_estado_inicial(
        payload.fecha_inicio, payload.fecha_fin, hoy
    )

    # 4. Validar límite de vigencia de 5 años
    validar_limite_vigencia_maxima(payload.fecha_inicio, payload.fecha_fin)

    # 5. Crear póliza con kilometraje inmutable
    poliza = Poliza(
        numero_poliza=payload.numero_poliza,
        cliente_id=payload.cliente_id,
        vehiculo_id=payload.vehiculo_id,
        inspeccion_id=payload.inspeccion_id,
        fecha_inicio=payload.fecha_inicio,
        fecha_fin=payload.fecha_fin,
        estado=estado_inicial,
        valor_asegurado=payload.valor_asegurado,
        prima_mensual=payload.prima_mensual,
        kilometraje_emision=payload.kilometraje_emision,
    )
    db.add(poliza)
    await db.flush()

    # 6. Deducibles (SC-2026-001): si se proveen se registran; si no, deducible por defecto general
    if payload.deducibles:
        for d in payload.deducibles:
            deducible = Deducible(
                poliza_id=poliza.id,
                tipo_siniestro=d.tipo_siniestro,
                porcentaje_valor=d.porcentaje_valor,
                monto_minimo_usd=d.monto_minimo_usd,
            )
            db.add(deducible)
    else:
        # Default deducible general (10%, $200 USD)
        db.add(
            Deducible(
                poliza_id=poliza.id,
                tipo_siniestro=TipoSiniestroEnum.GENERAL,
                porcentaje_valor=Decimal("10.00"),
                monto_minimo_usd=Decimal("200.00"),
            )
        )

    # 7. Coberturas
    if payload.coberturas:
        for c in payload.coberturas:
            cobertura = Cobertura(
                poliza_id=poliza.id,
                nombre=c.nombre,
                monto=c.monto,
            )
            db.add(cobertura)

    await db.commit()

    # Recargar con relaciones
    stmt = (
        select(Poliza)
        .options(selectinload(Poliza.deducibles), selectinload(Poliza.coberturas))
        .where(Poliza.id == poliza.id)
    )
    result = await db.execute(stmt)
    return result.scalar_one()


@router.get("", response_model=list[PolizaResponse])
async def listar_polizas(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Sequence[Poliza]:
    """Listar pólizas.
    
    Anti-BOLA estricto a nivel de consulta SQL:
    Los usuarios con rol 'cliente' únicamente pueden consultar pólizas asociadas
    a su propia identificación registrada (Sección 17.1).
    """
    stmt = (
        select(Poliza)
        .options(selectinload(Poliza.deducibles), selectinload(Poliza.coberturas))
        .order_by(Poliza.created_at.desc())
    )

    if current_user.rol == RolEnum.CLIENTE:
        stmt = stmt.join(Cliente, Poliza.cliente_id == Cliente.id).where(
            Cliente.usuario_id == current_user.id
        )

    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{id}", response_model=PolizaResponse)
async def obtener_poliza(
    id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Poliza:
    """Detalle de una póliza con Anti-BOLA en SQL."""
    stmt = (
        select(Poliza)
        .options(selectinload(Poliza.deducibles), selectinload(Poliza.coberturas))
        .where(Poliza.id == id)
    )

    if current_user.rol == RolEnum.CLIENTE:
        stmt = stmt.join(Cliente, Poliza.cliente_id == Cliente.id).where(
            Cliente.usuario_id == current_user.id
        )

    result = await db.execute(stmt)
    poliza = result.scalar_one_or_none()
    if not poliza:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Póliza no encontrada.",
        )
    return poliza


@router.get("/{id}/deducibles", response_model=list[DeducibleResponse])
async def consultar_deducibles(
    id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Sequence[Deducible]:
    """Consultar deducibles diferenciados de una póliza (SC-2026-001) con Anti-BOLA."""
    # Verificar propiedad de la póliza con Anti-BOLA
    stmt_pol = select(Poliza.id).where(Poliza.id == id)
    if current_user.rol == RolEnum.CLIENTE:
        stmt_pol = stmt_pol.join(Cliente, Poliza.cliente_id == Cliente.id).where(
            Cliente.usuario_id == current_user.id
        )

    poliza_valida = (await db.execute(stmt_pol)).scalar_one_or_none()
    if not poliza_valida:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Póliza no encontrada.",
        )

    stmt = select(Deducible).where(Deducible.poliza_id == id)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.patch("/{id}/estado", response_model=PolizaResponse)
async def actualizar_estado_poliza(
    id: uuid.UUID,
    payload: PolizaUpdateEstado,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> Poliza:
    """Actualizar estado de póliza. Dispara triggers de auditoría en PostgreSQL."""
    stmt = (
        select(Poliza)
        .options(selectinload(Poliza.deducibles), selectinload(Poliza.coberturas))
        .where(Poliza.id == id)
    )
    result = await db.execute(stmt)
    poliza = result.scalar_one_or_none()
    if not poliza:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Póliza no encontrada.",
        )

    poliza.estado = payload.estado
    await db.commit()
    await db.refresh(poliza)
    return poliza
