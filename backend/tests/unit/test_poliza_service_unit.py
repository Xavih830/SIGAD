"""Unit tests for PolizaService using InMemoryPolizaRepository without database."""

import uuid
from datetime import date, timedelta
from decimal import Decimal

import pytest

from app.core.exceptions import ConflictoDominioException, RecursoNoEncontradoException
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.cliente import Cliente
from app.models.usuario import RolEnum, Usuario
from app.models.vehiculo import Vehiculo
from app.repositories.poliza_repository import PolizaRepositoryProtocol
from app.schemas.poliza import PolizaCreate, PolizaUpdate
from app.services.poliza_service import PolizaService
from tests.fakes.in_memory_poliza_repository import InMemoryPolizaRepository


def _build_service_with_seed():
    repo = InMemoryPolizaRepository()
    assert isinstance(repo, PolizaRepositoryProtocol)

    admin = Usuario(
        id=uuid.uuid4(),
        email="admin@sigad.local",
        password_hash="x",
        rol=RolEnum.ADMIN,
        activo=True,
    )
    cliente_id = uuid.uuid4()
    vehiculo_id = uuid.uuid4()
    repo.clientes[cliente_id] = Cliente(
        id=cliente_id,
        identificacion="1710034065",
        nombres="Cliente Unit",
        email="cli@sigad.local",
        telefono="0999999999",
    )
    repo.vehiculos[vehiculo_id] = Vehiculo(
        id=vehiculo_id,
        cliente_id=cliente_id,
        placa="PBA-1234",
        marca="Toyota",
        modelo="Corolla",
        anio=2024,
    )
    return PolizaService(repo), repo, admin, cliente_id, vehiculo_id


@pytest.mark.asyncio
async def test_poliza_service_crear_y_actualizar_sin_bd():
    service, repo, _admin, cliente_id, vehiculo_id = _build_service_with_seed()
    hoy = date.today()
    payload = PolizaCreate(
        numero_poliza="POL-MEM-001",
        cliente_id=cliente_id,
        vehiculo_id=vehiculo_id,
        fecha_inicio=hoy,
        fecha_fin=hoy + timedelta(days=365),
        valor_asegurado=Decimal("22000.00"),
        prima_mensual=Decimal("120.00"),
        kilometraje_emision=10500,
    )

    creada = await service.crear_poliza(payload)
    assert creada.numero_poliza == "POL-MEM-001"
    assert creada.estado == EstadoPoliza.ACTIVA
    assert creada.version == 1
    assert len(repo.deducibles[creada.id]) == 1

    # Idempotente sin cambios -> versión no sube
    sin_cambio = await service.actualizar_poliza(
        creada.id,
        PolizaUpdate(prima_mensual=Decimal("120.00"), version=1),
    )
    assert sin_cambio.version == 1

    # Con cambio -> versión sube a 2
    actualizada = await service.actualizar_poliza(
        creada.id,
        PolizaUpdate(prima_mensual=Decimal("140.00"), version=1),
    )
    assert actualizada.version == 2
    assert actualizada.prima_mensual == Decimal("140.00")

    # Versión obsoleta -> 409
    with pytest.raises(ConflictoDominioException):
        await service.actualizar_poliza(
            creada.id,
            PolizaUpdate(prima_mensual=Decimal("150.00"), version=1),
        )


@pytest.mark.asyncio
async def test_poliza_service_anti_bola_sin_bd():
    service, _repo, _admin, cliente_id, vehiculo_id = _build_service_with_seed()
    otro_usuario = Usuario(
        id=uuid.uuid4(),
        email="ajeno@sigad.local",
        password_hash="x",
        rol=RolEnum.CLIENTE,
        activo=True,
    )
    hoy = date.today()
    creada = await service.crear_poliza(
        PolizaCreate(
            numero_poliza="POL-MEM-002",
            cliente_id=cliente_id,
            vehiculo_id=vehiculo_id,
            fecha_inicio=hoy,
            fecha_fin=hoy + timedelta(days=365),
            valor_asegurado=Decimal("18000.00"),
            prima_mensual=Decimal("95.00"),
            kilometraje_emision=5000,
        )
    )

    with pytest.raises(RecursoNoEncontradoException):
        await service.obtener_poliza(creada.id, current_user=otro_usuario)
