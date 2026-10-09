"""Scenario bundle factory for end-to-end and integration tests."""

from dataclasses import dataclass
from decimal import Decimal
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.cliente import Cliente
from app.models.poliza import Poliza
from app.models.usuario import RolEnum, Usuario
from app.models.vehiculo import Vehiculo
from tests.factories.models import create_cliente, create_poliza, create_user, create_vehiculo


@dataclass
class ScenarioBundle:
    """Convenient container holding pre-constructed test actors and entities."""

    admin_user: Usuario
    admin_token: str

    broker_user: Usuario
    broker_token: str

    user_a: Usuario
    cliente_a: Cliente
    vehiculo_a: Vehiculo
    poliza_a: Poliza
    token_a: str

    user_b: Usuario
    cliente_b: Cliente
    vehiculo_b: Vehiculo
    poliza_b: Poliza
    token_b: str

    @property
    def agente_token(self) -> str:
        """Typed alias for broker_token."""
        return self.broker_token


async def create_base_scenario(session: AsyncSession) -> ScenarioBundle:
    """Crea un escenario de prueba completo y vinculado."""
    admin_user = await create_user(
        session,
        email="admin@test.sigad.ec",
        nombre="Administrador Test",
        rol=RolEnum.ADMIN,
    )
    admin_token = create_access_token({"sub": str(admin_user.id)})

    broker_user = await create_user(
        session,
        email="broker@test.sigad.ec",
        nombre="Broker Test",
        rol=RolEnum.ADMIN,
    )
    broker_token = create_access_token({"sub": str(broker_user.id)})

    user_a = await create_user(
        session,
        email="cliente.a@test.sigad.ec",
        nombre="Carlos Test Pérez",
        rol=RolEnum.CLIENTE,
    )
    cliente_a = await create_cliente(
        session,
        usuario_id=user_a.id,
        identificacion="0926687856",
        nombres="Carlos Test Pérez",
        email=user_a.email,
    )
    vehiculo_a = await create_vehiculo(
        session,
        cliente_id=cliente_a.id,
        placa="GPA-1234",
        marca="Toyota",
        modelo="Corolla Cross",
    )
    poliza_a = await create_poliza(
        session,
        cliente_id=cliente_a.id,
        vehiculo_id=vehiculo_a.id,
        numero_poliza="POL-SCENARIO-A01",
        estado=EstadoPoliza.ACTIVA,
        valor_asegurado=Decimal("22000.00"),
        prima_mensual=Decimal("70.00"),
    )
    token_a = create_access_token({"sub": str(user_a.id)})

    user_b = await create_user(
        session,
        email="cliente.b@test.sigad.ec",
        nombre="María Test León",
        rol=RolEnum.CLIENTE,
    )
    cliente_b = await create_cliente(
        session,
        usuario_id=user_b.id,
        identificacion="1710034065",
        nombres="María Test León",
        email=user_b.email,
    )
    vehiculo_b = await create_vehiculo(
        session,
        cliente_id=cliente_b.id,
        placa="PBX-5678",
        marca="Chevrolet",
        modelo="Sail",
    )
    poliza_b = await create_poliza(
        session,
        cliente_id=cliente_b.id,
        vehiculo_id=vehiculo_b.id,
        numero_poliza="POL-SCENARIO-B02",
        estado=EstadoPoliza.ACTIVA,
        valor_asegurado=Decimal("14000.00"),
        prima_mensual=Decimal("45.00"),
    )
    token_b = create_access_token({"sub": str(user_b.id)})

    return ScenarioBundle(
        admin_user=admin_user,
        admin_token=admin_token,
        broker_user=broker_user,
        broker_token=broker_token,
        user_a=user_a,
        cliente_a=cliente_a,
        vehiculo_a=vehiculo_a,
        poliza_a=poliza_a,
        token_a=token_a,
        user_b=user_b,
        cliente_b=cliente_b,
        vehiculo_b=vehiculo_b,
        poliza_b=poliza_b,
        token_b=token_b,
    )
