"""Shared fixtures for integration tests against the database.

Uses modern pytest-asyncio (v0.24+) loop_scope="session" to share the
session event loop with the real SQLAlchemy production connection pool.
"""

from datetime import date, timedelta
from decimal import Decimal
import uuid

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password
from app.db.session import async_session_factory
from app.domain.poliza_evaluator import EstadoPoliza
from app.main import app
from app.models.cliente import Cliente
from app.models.poliza import Poliza
from app.models.usuario import RolEnum, Usuario
from app.models.vehiculo import Vehiculo

pytestmark = pytest.mark.asyncio(loop_scope="session")


@pytest_asyncio.fixture(loop_scope="session")
async def db_session():
    """Provide an async database session using the real application session factory."""
    async with async_session_factory() as session:
        yield session


@pytest_asyncio.fixture(scope="session", loop_scope="session")
async def seed_data():
    """Seed corporate admin, and two distinct clients (Cliente A and Cliente B) with vehicles."""
    async with async_session_factory() as db_session:
        # 1. Admin user
        admin_id = uuid.uuid4()
        admin_user = Usuario(
            id=admin_id,
            email=f"admin_{admin_id.hex[:6]}@sigad.ec",
            password_hash=hash_password("Admin#2026"),
            nombre="Admin Integracion",
            rol=RolEnum.ADMIN,
            activo=True,
        )
        db_session.add(admin_user)

        # 2. Cliente A (User + Cliente record)
        user_a_id = uuid.uuid4()
        user_a = Usuario(
            id=user_a_id,
            email=f"client_a_{user_a_id.hex[:6]}@test.ec",
            password_hash=hash_password("ClienteA#2026"),
            nombre="Cliente A Perez",
            rol=RolEnum.CLIENTE,
            activo=True,
        )
        db_session.add(user_a)

        cliente_a = Cliente(
            id=uuid.uuid4(),
            identificacion=f"09{uuid.uuid4().int % 90000000 + 10000000}",
            nombres="Cliente A Perez",
            email=user_a.email,
            telefono="0991112233",
            usuario_id=user_a.id,
        )
        db_session.add(cliente_a)

        # 3. Cliente B (User + Cliente record)
        user_b_id = uuid.uuid4()
        user_b = Usuario(
            id=user_b_id,
            email=f"client_b_{user_b_id.hex[:6]}@test.ec",
            password_hash=hash_password("ClienteB#2026"),
            nombre="Cliente B Gomez",
            rol=RolEnum.CLIENTE,
            activo=True,
        )
        db_session.add(user_b)

        cliente_b = Cliente(
            id=uuid.uuid4(),
            identificacion=f"09{uuid.uuid4().int % 90000000 + 10000000}",
            nombres="Cliente B Gomez",
            email=user_b.email,
            telefono="0994445566",
            usuario_id=user_b.id,
        )
        db_session.add(cliente_b)
        await db_session.flush()

        # 4. Vehiculos
        vehiculo_a = Vehiculo(
            id=uuid.uuid4(),
            placa=f"P{uuid.uuid4().hex[:2].upper()}-{uuid.uuid4().int % 9000 + 1000}",
            marca="Toyota",
            modelo="Yaris",
            anio=2022,
            cliente_id=cliente_a.id,
        )
        vehiculo_b = Vehiculo(
            id=uuid.uuid4(),
            placa=f"P{uuid.uuid4().hex[:2].upper()}-{uuid.uuid4().int % 9000 + 1000}",
            marca="Chevrolet",
            modelo="Onix",
            anio=2023,
            cliente_id=cliente_b.id,
        )
        db_session.add_all([vehiculo_a, vehiculo_b])
        await db_session.flush()

        # 5. Polizas
        poliza_a = Poliza(
            id=uuid.uuid4(),
            numero_poliza=f"POL-A-{uuid.uuid4().hex[:8].upper()}",
            cliente_id=cliente_a.id,
            vehiculo_id=vehiculo_a.id,
            fecha_inicio=date.today() - timedelta(days=30),
            fecha_fin=date.today() + timedelta(days=335),
            estado=EstadoPoliza.ACTIVA,
            valor_asegurado=Decimal("15000.00"),
            prima_mensual=Decimal("45.50"),
            kilometraje_emision=25000,
        )
        poliza_b = Poliza(
            id=uuid.uuid4(),
            numero_poliza=f"POL-B-{uuid.uuid4().hex[:8].upper()}",
            cliente_id=cliente_b.id,
            vehiculo_id=vehiculo_b.id,
            fecha_inicio=date.today() - timedelta(days=60),
            fecha_fin=date.today() + timedelta(days=305),
            estado=EstadoPoliza.ACTIVA,
            valor_asegurado=Decimal("18000.00"),
            prima_mensual=Decimal("55.00"),
            kilometraje_emision=35000,
        )
        db_session.add_all([poliza_a, poliza_b])
        await db_session.commit()

        tokens = {
            "admin": create_access_token({"sub": str(admin_user.id)}),
            "cliente_a": create_access_token({"sub": str(user_a.id)}),
            "cliente_b": create_access_token({"sub": str(user_b.id)}),
        }

        return {
            "admin_user": admin_user,
            "user_a": user_a,
            "cliente_a": cliente_a,
            "user_b": user_b,
            "cliente_b": cliente_b,
            "vehiculo_a": vehiculo_a,
            "vehiculo_b": vehiculo_b,
            "poliza_a": poliza_a,
            "poliza_b": poliza_b,
            "tokens": tokens,
        }


def make_client(token: str | None = None) -> AsyncClient:
    """Create test AsyncClient with optional Bearer token."""
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test", headers=headers)
