"""Clientes endpoint — onboarding, listing, and OTP generation for mobile linking."""

import logging
import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_role, get_current_user
from app.core.exceptions import RecursoNoEncontradoException
from app.db.session import get_db
from app.models.usuario import RolEnum, Usuario
from app.schemas.base import PaginatedResponse
from app.schemas.cliente import ClienteCreate, ClienteResponse, ClienteUpdate
from app.services.cliente_service import ClienteService
from app.services.smtp_service import smtp_service

logger = logging.getLogger("sigad.clientes")

router = APIRouter(prefix="/clientes", tags=["Clientes"])


@router.post("", response_model=ClienteResponse, status_code=status.HTTP_201_CREATED)
async def registrar_cliente(
    body: ClienteCreate,
    background_tasks: BackgroundTasks,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> ClienteResponse:
    """Registra un nuevo cliente asegurado y genera su código OTP de vinculación inicial."""
    service = ClienteService(db)
    nuevo_cliente, codigo_plano = await service.registrar(body)

    if nuevo_cliente.email:
        background_tasks.add_task(
            smtp_service.send_otp_email,
            destinatario=nuevo_cliente.email,
            codigo_otp=codigo_plano,
            nombres=nuevo_cliente.nombres,
        )

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


@router.get("", response_model=PaginatedResponse[ClienteResponse])
async def listar_clientes(
    q: str | None = Query(None, description="Búsqueda por nombre o identificación"),
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> PaginatedResponse[ClienteResponse]:
    """Lista todos los clientes registrados de forma paginada."""
    service = ClienteService(db)
    clientes, total = await service.listar(q=q, skip=skip, limit=limit)
    return PaginatedResponse(
        items=[ClienteResponse.model_validate(c) for c in clientes],
        total=total,
        skip=skip,
        limit=limit,
    )


@router.get("/{cliente_id}", response_model=ClienteResponse)
async def obtener_cliente(
    cliente_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ClienteResponse:
    """Obtiene el detalle de un cliente asegurado."""
    service = ClienteService(db)
    cliente = await service.obtener(cliente_id)

    if current_user.rol not in (RolEnum.ADMIN, RolEnum.AGENTE):
        if cliente.usuario_id != current_user.id:
            raise RecursoNoEncontradoException("Recurso no encontrado.")

    return ClienteResponse.model_validate(cliente)


@router.patch("/{cliente_id}", response_model=ClienteResponse)
async def actualizar_cliente(
    cliente_id: uuid.UUID,
    body: ClienteUpdate,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> ClienteResponse:
    """Actualiza datos de contacto de un cliente asegurado (ADMIN y AGENTE)."""
    service = ClienteService(db)
    cliente = await service.actualizar(cliente_id, body)
    return ClienteResponse.model_validate(cliente)


@router.delete("/{cliente_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_cliente(
    cliente_id: uuid.UUID,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN)),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Elimina un cliente si no tiene registros asociados (Solo ADMIN)."""
    service = ClienteService(db)
    await service.eliminar(cliente_id)


@router.post("/{cliente_id}/otp", response_model=ClienteResponse)
async def regenerar_otp_cliente(
    cliente_id: uuid.UUID,
    background_tasks: BackgroundTasks,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> ClienteResponse:
    """Regenera un nuevo código OTP de vinculación para un cliente existente."""
    service = ClienteService(db)
    cliente, codigo_plano = await service.regenerar_otp(cliente_id)

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
