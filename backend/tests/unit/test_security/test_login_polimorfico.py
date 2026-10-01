"""TEST 2: Polymorphic login — email-based lookup.

Uses the FastAPI TestClient to verify that login with an email address
performs a direct lookup in the `usuarios` table.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.main import app
from app.models.usuario import RolEnum
from tests.factories import (
    ADMIN_EMAIL,
    ADMIN_PASSWORD,
    create_mock_admin_user,
    login_payload,
)


@pytest.mark.asyncio
async def test_login_polimorfico():
    """Login with email should find user directly in usuarios table."""
    fake_user = create_mock_admin_user()

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
                json=login_payload(ADMIN_EMAIL, ADMIN_PASSWORD),
            )

        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["email"] == ADMIN_EMAIL
        assert data["user"]["rol"] == RolEnum.ADMIN.value
    finally:
        app.dependency_overrides.clear()
