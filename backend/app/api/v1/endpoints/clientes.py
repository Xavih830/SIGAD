"""Clientes endpoint — onboarding, listing, and OTP generation for mobile linking."""

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import compute_otp_hmac, generate_otp_code
from app.db.session import get_db
from app.models.cliente import Cliente
from app.models.codigo_vinculacion import CodigoVinculacion
from app.schemas.cliente import ClienteCreate, ClienteResponse
from app.services.smtp_service import smtp_service

logger = logging.getLogger("sigad.clientes")

router = APIRouter(prefix="/clientes", tags=["Clientes"])


@router.post("", response_model=ClienteResponse, status_code=status.HTTP_201_CREATED)
async def registrar_cliente(
    body: ClienteCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> ClienteResponse:
    """Registra un nuevo cliente asegurado y genera su código OTP de vinculación inicial."""
    identificacion = body.identificacion.strip()

    # Verificar si ya existe cliente con esa identificación
    stmt = select(Cliente).where(Cliente.identificacion == identificacion)
    res = await db.execute(stmt)
    existing = res.scalar_one_or_none()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya existe un cliente registrado con la cédula {identificacion}.",
        )

    # Crear cliente en base de datos
    nuevo_cliente = Cliente(
        identificacion=identificacion,
        nombres=body.nombres.strip(),
        email=body.email.lower() if body.email else None,
        telefono=body.telefono.strip() if body.telefono else None,
    )
    db.add(nuevo_cliente)
    await db.flush()  # Obtener ID para el código de vinculación

    # Generar código OTP de 6 dígitos
    codigo_plano = generate_otp_code(6)
    codigo_hmac = compute_otp_hmac(codigo_plano, settings.OTP_SECRET_KEY_ACTUAL)
    expira_en = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRATION_MINUTES)

    codigo_obj = CodigoVinculacion(
        cliente_id=nuevo_cliente.id,
        codigo_hmac=codigo_hmac,
        expira_en=expira_en,
        consumido=False,
        intentos_fallidos=0,
    )
    db.add(codigo_obj)
    await db.commit()
    await db.refresh(nuevo_cliente)

    logger.info("cliente_registrado id=%s cedula=%s", nuevo_cliente.id, identificacion)

    # Disparo asíncrono como canal de respaldo vía SMTP
    if nuevo_cliente.email:
        background_tasks.add_task(
            smtp_service.send_otp_email,
            destinatario=nuevo_cliente.email,
            codigo_otp=codigo_plano,
            nombres=nuevo_cliente.nombres,
        )

    # Retornar datos con el código plano para que el panel web lo presente y permita copiarlo a WhatsApp
    return ClienteResponse(
        id=nuevo_cliente.id,
        identificacion=nuevo_cliente.identificacion,
        nombres=nuevo_cliente.nombres,
        email=nuevo_cliente.email,
        telefono=nuevo_cliente.telefono,
        usuario_id=nuevo_cliente.usuario_id,
        created_at=nuevo_cliente.created_at,
        codigo_vinculacion=codigo_plano,
    )


@router.get("", response_model=List[ClienteResponse])
async def listar_clientes(
    q: Optional[str] = Query(None, description="Búsqueda por nombre o cédula"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
) -> List[ClienteResponse]:
    """Lista todos los clientes registrados."""
    stmt = select(Cliente).order_by(desc(Cliente.created_at)).offset(skip).limit(limit)
    if q:
        search_filter = f"%{q.strip()}%"
        stmt = stmt.where(
            (Cliente.nombres.ilike(search_filter)) | (Cliente.identificacion.ilike(search_filter))
        )

    res = await db.execute(stmt)
    clientes = res.scalars().all()
    return [ClienteResponse.model_validate(c) for c in clientes]


@router.get("/{cliente_id}", response_model=ClienteResponse)
async def obtener_cliente(
    cliente_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
) -> ClienteResponse:
    """Obtiene el detalle de un cliente asegurado."""
    stmt = select(Cliente).where(Cliente.id == cliente_id)
    res = await db.execute(stmt)
    cliente = res.scalar_one_or_none()

    if not cliente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cliente no encontrado.",
        )

    return ClienteResponse.model_validate(cliente)


@router.post("/{cliente_id}/otp", response_model=ClienteResponse)
async def regenerar_otp_cliente(
    cliente_id: uuid.UUID,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> ClienteResponse:
    """Regenera un nuevo código OTP de vinculación para un cliente existente."""
    stmt = select(Cliente).where(Cliente.id == cliente_id)
    res = await db.execute(stmt)
    cliente = res.scalar_one_or_none()

    if not cliente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cliente no encontrado.",
        )

    codigo_plano = generate_otp_code(6)
    codigo_hmac = compute_otp_hmac(codigo_plano, settings.OTP_SECRET_KEY_ACTUAL)
    expira_en = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRATION_MINUTES)

    codigo_obj = CodigoVinculacion(
        cliente_id=cliente.id,
        codigo_hmac=codigo_hmac,
        expira_en=expira_en,
        consumido=False,
        intentos_fallidos=0,
    )
    db.add(codigo_obj)
    await db.commit()
    await db.refresh(cliente)

    logger.info("otp_regenerado cliente_id=%s cedula=%s", cliente.id, cliente.identificacion)

    if cliente.email:
        background_tasks.add_task(
            smtp_service.send_otp_email,
            destinatario=cliente.email,
            codigo_otp=codigo_plano,
            nombres=cliente.nombres,
        )

    return ClienteResponse(
        id=cliente.id,
        identificacion=cliente.identificacion,
        nombres=cliente.nombres,
        email=cliente.email,
        telefono=cliente.telefono,
        usuario_id=cliente.usuario_id,
        created_at=cliente.created_at,
        codigo_vinculacion=codigo_plano,
    )
