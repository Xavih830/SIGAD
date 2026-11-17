"""Polizas REST endpoints delegating domain logic to PolizaService."""

import uuid
from collections.abc import Sequence

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_role, get_current_user
from app.core.constants import DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT
from app.db.session import get_db
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.deducible import Deducible
from app.models.poliza import Poliza
from app.models.usuario import RolEnum, Usuario
from app.repositories.poliza_repository import PolizaRepository
from app.schemas.base import PaginatedResponse
from app.schemas.deducible import DeducibleResponse
from app.schemas.poliza import (
    HistorialCambioResponse,
    PolizaCreate,
    PolizaResponse,
    PolizaUpdate,
    PolizaUpdateEstado,
)
from app.services.poliza_service import PolizaService

router = APIRouter(prefix="/polizas", tags=["Pólizas"])


def get_poliza_service(db: AsyncSession = Depends(get_db)) -> PolizaService:
    """Inyección de PolizaService con PolizaRepository."""
    return PolizaService(PolizaRepository(db))


@router.post("", response_model=PolizaResponse, status_code=status.HTTP_201_CREATED)
async def crear_poliza(
    payload: PolizaCreate,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    service: PolizaService = Depends(get_poliza_service),
) -> Poliza:
    """Emisión formal de póliza con snapshot inmutable de kilometraje y cálculo de estado inicial."""
    return await service.crear_poliza(payload)


@router.get("", response_model=list[PolizaResponse])
async def listar_polizas(
    estado: EstadoPoliza | None = Query(None, description="Filtrar pólizas por estado."),
    skip: int = Query(0, ge=0, description="Número de registros a omitir."),
    limit: int = Query(
        DEFAULT_PAGE_LIMIT,
        ge=1,
        le=MAX_PAGE_LIMIT,
        description="Límite máximo de registros a retornar.",
    ),
    current_user: Usuario = Depends(get_current_user),
    service: PolizaService = Depends(get_poliza_service),
) -> Sequence[Poliza]:
    """Listar pólizas con paginación y protección Anti-BOLA estricta a nivel de consulta SQL."""
    return await service.listar_polizas(
        current_user=current_user, estado=estado, skip=skip, limit=limit
    )


@router.get("/{id}", response_model=PolizaResponse)
async def obtener_poliza(
    id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    service: PolizaService = Depends(get_poliza_service),
) -> Poliza:
    """Detalle de una póliza con Anti-BOLA en SQL."""
    return await service.obtener_poliza(id, current_user=current_user)


@router.get("/{id}/deducibles", response_model=list[DeducibleResponse])
async def consultar_deducibles(
    id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    service: PolizaService = Depends(get_poliza_service),
) -> Sequence[Deducible]:
    return await service.consultar_deducibles(id, current_user=current_user)


@router.patch("/{id}/estado", response_model=PolizaResponse)
async def actualizar_estado_poliza(
    id: uuid.UUID,
    payload: PolizaUpdateEstado,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    service: PolizaService = Depends(get_poliza_service),
) -> Poliza:
    """Actualizar estado de póliza. Dispara triggers de auditoría en PostgreSQL."""
    return await service.actualizar_estado(id, payload)


@router.put("/{id}", response_model=PolizaResponse)
async def actualizar_poliza(
    id: uuid.UUID,
    payload: PolizaUpdate,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    service: PolizaService = Depends(get_poliza_service),
) -> Poliza:
    """Modificación idempotente de póliza con control optimista de versión."""
    return await service.actualizar_poliza(id, payload)


@router.get("/{id}/historial", response_model=PaginatedResponse[HistorialCambioResponse])
async def listar_historial_poliza(
    id: uuid.UUID,
    skip: int = Query(0, ge=0, description="Número de registros a omitir."),
    limit: int = Query(
        DEFAULT_PAGE_LIMIT,
        ge=1,
        le=MAX_PAGE_LIMIT,
        description="Límite máximo de registros a retornar.",
    ),
    current_user: Usuario = Depends(get_current_user),
    service: PolizaService = Depends(get_poliza_service),
) -> PaginatedResponse[HistorialCambioResponse]:
    """Listado paginado de cambios auditados para una póliza."""
    return await service.listar_historial(id, current_user=current_user, skip=skip, limit=limit)
