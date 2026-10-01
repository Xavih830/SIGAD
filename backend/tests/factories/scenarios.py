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

    def to_dict(self) -> dict:
        """Compatibility dictionary format for legacy seed_data fixtures."""
        return {
            "admin_user": self.admin_user,
            "user_a": self.user_a,
            "cliente_a": self.cliente_a,
            "user_b": self.user_b,
            "cliente_b": self.cliente_b,
            "vehiculo_a": self.vehiculo_a,
            "vehiculo_b": self.vehiculo_b,
            "poliza_a": self.poliza_a,
            "poliza_b": self.poliza_b,
            "admin_token": self.admin_token,
            "agente_token": self.broker_token,
            "tokens": {
                "admin": self.admin_token,
                "broker": self.broker_token,
                "cliente_a": self.token_a,
                "cliente_b": self.token_b,
            },
        }


async def create_base_scenario(session: AsyncSession) -> ScenarioBundle:
    """Create a complete, fully linked, valid test scenario on demand.
    
    Creates:
    1. Admin user with access token.
    2. Broker user with access token.
    3. Cliente A (with valid Módulo 10 Cédula, linked user account, ANT vehicle, and active policy).
    4. Cliente B (distinct tenant, with valid Cédula, linked user, ANT vehicle, and active policy).
    
    Executed within the caller's AsyncSession (typically with Savepoint isolation).
    """
    # 1. Admin
    admin_user = await create_user(
        session,
        email="admin@test.sigad.ec",
        nombre="Administrador Test",
        rol=RolEnum.ADMIN,
    )
    admin_token = create_access_token({"sub": str(admin_user.id)})

    # 2. Broker
    broker_user = await create_user(
        session,
        email="broker@test.sigad.ec",
        nombre="Broker Test",
        rol=RolEnum.ADMIN,
    )
    broker_token = create_access_token({"sub": str(broker_user.id)})

    # 3. Cliente A (Guayas - 0926687856)
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

    # 4. Cliente B (Pichincha - 1710034065)
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
