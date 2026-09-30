"""TEST 2: Polymorphic login — email-based lookup.

Uses the FastAPI TestClient to verify that login with an email address
performs a direct lookup in the `usuarios` table.
"""

import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.security import hash_password
from app.main import app
from app.models.usuario import RolEnum


@pytest.mark.asyncio
async def test_login_polimorfico():
    """Login with email should find user directly in usuarios table."""
    fake_user = MagicMock()
    fake_user.id = uuid.uuid4()
    fake_user.email = "admin@sigad.ec"
    fake_user.password_hash = hash_password("Admin#SIGAD24")
    fake_user.nombre = "Administrador del Sistema"
    fake_user.rol = RolEnum.ADMIN
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
                json={"identificador": "admin@sigad.ec", "password": "Admin#SIGAD24"},
            )

        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["email"] == "admin@sigad.ec"
        assert data["user"]["rol"] == "admin"
    finally:
        app.dependency_overrides.clear()
