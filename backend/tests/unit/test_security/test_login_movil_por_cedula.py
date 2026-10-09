"""Mobile login by cédula — polymorphic path via clientes JOIN.

Verifies that numeric identifiers trigger a JOIN through clientes
to find the associated usuario.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.main import app
from app.models.usuario import RolEnum
from tests.factories import (
    CLIENTE_CEDULA,
    CLIENTE_EMAIL,
    CLIENTE_PASSWORD,
    create_mock_cliente_user,
    login_payload,
)


@pytest.mark.asyncio
async def test_login_movil_por_cedula():
    """Login with cédula should perform JOIN through clientes → usuarios."""
    fake_user = create_mock_cliente_user()

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = fake_user

    mock_session = AsyncMock()
    mock_session.execute.return_value = mock_result
    mock_session.commit = AsyncMock()

    async def fake_get_db():
        yield mock_session

    app.dependency_overrides.clear()
    app.dependency_overrides[get_db] = fake_get_db

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/api/v1/auth/login",
                json=login_payload(CLIENTE_CEDULA, CLIENTE_PASSWORD),
            )

        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
        data = response.json()
        assert "access_token" in data
        assert data["user"]["rol"] == RolEnum.CLIENTE.value
        assert data["user"]["email"] == CLIENTE_EMAIL
    finally:
        app.dependency_overrides.clear()
