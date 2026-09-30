"""TEST 3: Mobile login by cédula — polymorphic path via clientes JOIN.

Verifies that numeric identifiers trigger a JOIN through clientes
to find the associated usuario.
"""

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.security import hash_password
from app.main import app
from app.models.usuario import RolEnum


@pytest.mark.asyncio
async def test_login_movil_por_cedula():
    """Login with cédula should perform JOIN through clientes → usuarios."""
    fake_user = MagicMock()
    fake_user.id = uuid.uuid4()
    fake_user.email = "m.leon@hotmail.com"
    fake_user.password_hash = hash_password("Maria#2024")
    fake_user.nombre = "María José León Andrade"
    fake_user.rol = RolEnum.CLIENTE
    fake_user.activo = True

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = fake_user

    mock_session = AsyncMock()
    mock_session.execute.return_value = mock_result
    mock_session.commit = AsyncMock()

    async def fake_get_db():
        yield mock_session

    app.dependency_overrides.clear()
    from app.db.session import get_db
    app.dependency_overrides[get_db] = fake_get_db

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/api/v1/auth/login",
                json={"identificador": "0923456789", "password": "Maria#2024"},
            )

        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
        data = response.json()
        assert "access_token" in data
        assert data["user"]["rol"] == "cliente"
        assert data["user"]["email"] == "m.leon@hotmail.com"
    finally:
        app.dependency_overrides.clear()
