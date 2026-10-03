"""Shared fixtures for integration tests with complete Savepoint isolation and Factory support.

Architectural Guarantees:
1. Dedicated Test Database: Always targets `sigad_test_db` to protect development & production data.
2. NullPool: Connections are strictly isolated per test, preventing connection pool poisoning across async event loops.
3. Savepoint Rollback Isolation: Every test runs inside an outer transaction (`join_transaction_mode="create_savepoint"`).
   Any internal `commit()` from route handlers creates a SAVEPOINT instead of persisting to disk.
   At the end of each test, `rollback()` instantly restores the database to its pristine state.
4. FastAPI Dependency Override: `app.dependency_overrides[get_db]` injects the transactional test session,
   ensuring that API HTTP requests and test asserts execute in the exact same transactional scope.
5. Zero Test Data Scattering: Test entities and payloads are provisioned cleanly via factories.
"""

import os
from typing import AsyncGenerator, Callable

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.pool import NullPool

from app.api.deps import get_db
from app.core.rate_limit import rate_limiter
from app.core.security import create_access_token
from app.main import app
from app.services.smtp_service import smtp_service
from tests.factories.fixtures import TEST_MAILPIT_HOST
from tests.factories.models import (
    create_cliente,
    create_poliza,
    create_user,
    create_vehiculo,
)
from tests.factories.scenarios import ScenarioBundle, create_base_scenario

from app.core.config import _CANONICAL_ROOT_ENV
from dotenv import load_dotenv

load_dotenv(_CANONICAL_ROOT_ENV)

TEST_DATABASE_URL = os.environ["TEST_DATABASE_URL"]

# Conectar smtp_service de pruebas al host local de Mailpit
smtp_service.smtp_host = TEST_MAILPIT_HOST

# Engine configured with NullPool to prevent connection reuse and event-loop leakage
test_engine = create_async_engine(
    TEST_DATABASE_URL,
    poolclass=NullPool,
    echo=False,
)

pytestmark = pytest.mark.asyncio(loop_scope="session")


@pytest_asyncio.fixture(scope="function")
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Function-scoped transactional session with Savepoint rollback.

    Every operation during the test runs inside an uncommitted transaction.
    Teardown rolls back everything, leaving the database completely clean.
    """
    rate_limiter.reset()
    async with test_engine.connect() as connection:
        transaction = await connection.begin()
        session = AsyncSession(
            bind=connection,
            join_transaction_mode="create_savepoint",
            expire_on_commit=False,
        )

        app.dependency_overrides[get_db] = lambda: session

        try:
            yield session
        finally:
            app.dependency_overrides.pop(get_db, None)
            await transaction.rollback()
            await session.close()


@pytest_asyncio.fixture(scope="function")
async def base_scenario(db_session: AsyncSession) -> ScenarioBundle:
    """Generate a clean, fully populated test scenario within the active savepoint transaction."""
    return await create_base_scenario(db_session)



# ─────────────────────────────────────────────────────────────────────────────
# Factory-as-Fixture Helpers (Eliminates test data scattering)
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture
def user_factory(db_session: AsyncSession) -> Callable:
    """Factory fixture to create users with custom overrides."""
    async def _maker(**kwargs):
        return await create_user(db_session, **kwargs)
    return _maker


@pytest.fixture
def cliente_factory(db_session: AsyncSession) -> Callable:
    """Factory fixture to create clients with valid Módulo 10 cédula."""
    async def _maker(**kwargs):
        return await create_cliente(db_session, **kwargs)
    return _maker


@pytest.fixture
def vehiculo_factory(db_session: AsyncSession) -> Callable:
    """Factory fixture to create vehicles with valid ANT plates."""
    async def _maker(**kwargs):
        return await create_vehiculo(db_session, **kwargs)
    return _maker


@pytest.fixture
def poliza_factory(db_session: AsyncSession) -> Callable:
    """Factory fixture to create policies with valid dates and deductibles."""
    async def _maker(**kwargs):
        return await create_poliza(db_session, **kwargs)
    return _maker


def make_client(token: str | None = None) -> AsyncClient:
    """Create test AsyncClient targeting the in-memory ASGI app with optional Bearer token."""
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test", headers=headers)


@pytest_asyncio.fixture(scope="function")
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Function-scoped test client targeting in-memory ASGI app."""
    async with make_client(None) as c:
        yield c
