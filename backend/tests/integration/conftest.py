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
from sqlalchemy import select, text
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
    """Retrieve existing seeded test clients and admin from the database without ingesting or polluting real data."""
    async with async_session_factory() as db_session:
        # 1. Admin
        res_adm = await db_session.execute(select(Usuario).where(Usuario.email == "admin@sigad.ec"))
        admin_user = res_adm.scalar_one_or_none()
        if not admin_user:
            admin_user = Usuario(
                email="admin@sigad.ec",
                password_hash=hash_password("123456789"),
                nombre="Administrador del Sistema",
                rol=RolEnum.ADMIN,
                activo=True,
            )
            db_session.add(admin_user)
            await db_session.flush()

        # 2. Cliente A (0926687856)
        res_ca = await db_session.execute(select(Cliente).where(Cliente.identificacion == "0926687856"))
        cliente_a = res_ca.scalar_one_or_none()
        res_ua = await db_session.execute(select(Usuario).where(Usuario.id == cliente_a.usuario_id))
        user_a = res_ua.scalar_one_or_none()
        res_va = await db_session.execute(select(Vehiculo).where(Vehiculo.cliente_id == cliente_a.id))
        vehiculo_a = res_va.scalars().first()
        res_pa = await db_session.execute(select(Poliza).where(Poliza.cliente_id == cliente_a.id))
        poliza_a = res_pa.scalars().first()

        # 3. Cliente B (1710034065)
        res_cb = await db_session.execute(select(Cliente).where(Cliente.identificacion == "1710034065"))
        cliente_b = res_cb.scalar_one_or_none()
        res_ub = await db_session.execute(select(Usuario).where(Usuario.id == cliente_b.usuario_id))
        user_b = res_ub.scalar_one_or_none()
        res_vb = await db_session.execute(select(Vehiculo).where(Vehiculo.cliente_id == cliente_b.id))
        vehiculo_b = res_vb.scalars().first()
        res_pb = await db_session.execute(select(Poliza).where(Poliza.cliente_id == cliente_b.id))
        poliza_b = res_pb.scalars().first()

        tokens = {
            "admin": create_access_token({"sub": str(admin_user.id)}),
            "cliente_a": create_access_token({"sub": str(user_a.id)}),
            "cliente_b": create_access_token({"sub": str(user_b.id)}),
        }

        try:
            yield {
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
        finally:
            # Teardown: Eliminar rigurosamente todos los registros temporales creados durante los tests
            # para no contaminar la base de datos de desarrollo ni dejar artefactos residuales.
            async with async_session_factory() as cleanup_session:
                await cleanup_session.execute(
                    text("DELETE FROM documentos WHERE nombre_archivo LIKE 'cedula_cliente_%' OR nombre_archivo LIKE 'test_%'")
                )
                await cleanup_session.execute(
                    text(
                        """
                        DELETE FROM polizas WHERE numero_poliza LIKE 'POL-TEST-%'
                           OR numero_poliza LIKE 'POL-SNAP-%'
                           OR numero_poliza LIKE 'POL-FAIL-%'
                           OR numero_poliza LIKE 'POL-ZERO-%'
                           OR numero_poliza LIKE 'POL-5YR-%'
                           OR numero_poliza LIKE 'POL-HACK-%'
                        """
                    )
                )
                await cleanup_session.execute(
                    text("DELETE FROM vehiculos WHERE placa LIKE 'PBA-TEST-%' OR modelo = 'Vehiculo Temporal Test'")
                )
                await cleanup_session.execute(
                    text("DELETE FROM clientes WHERE email LIKE 'test_%' OR nombres LIKE 'Cliente Test%'")
                )
                await cleanup_session.commit()


def make_client(token: str | None = None) -> AsyncClient:
    """Create test AsyncClient with optional Bearer token."""
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test", headers=headers)

