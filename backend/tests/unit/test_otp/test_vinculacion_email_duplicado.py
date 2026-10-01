"""TEST 17: Detección de colisión de email lanzando EmailDuplicadoException (HTTP 409)."""

from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.exceptions import EmailDuplicadoException
from app.core.rate_limit import rate_limiter
from app.db.session import get_db
from app.main import app
from tests.factories import (
    MSG_EMAIL_DUPLICADO,
    create_mock_cliente,
    create_mock_user,
    vinculacion_payload,
)


@pytest.mark.asyncio
async def test_vinculacion_email_duplicado():
    """When target email is already registered in usuarios, abort immediately with EmailDuplicadoException (HTTP 409)."""
    rate_limiter.reset()

    duplicate_email = "duplicado@cliente.ec"
    fake_cliente = create_mock_cliente(email=duplicate_email)
    fake_usuario = create_mock_user(email=duplicate_email)

    # Mock DB session
    mock_session = AsyncMock()

    # Sequence of queries:
    # 1. select(Cliente) -> returns fake_cliente
    # 2. select(Usuario) for email duplicate check -> returns fake_usuario (conflict!)
    res_cliente = MagicMock()
    res_cliente.scalar_one_or_none.return_value = fake_cliente

    res_usuario = MagicMock()
    res_usuario.scalar_one_or_none.return_value = fake_usuario

    mock_session.execute.side_effect = [res_cliente, res_usuario]
    mock_session.commit = AsyncMock()
    mock_session.flush = AsyncMock()

    async def fake_get_db():
        yield mock_session

    app.dependency_overrides.clear()
    app.dependency_overrides[get_db] = fake_get_db

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/api/v1/auth/vinculacion",
                json=vinculacion_payload(),
            )

        assert response.status_code == 409, f"Expected 409, got {response.status_code}: {response.text}"
        data = response.json()
        assert data["detail"] == MSG_EMAIL_DUPLICADO

        # Verify that no changes were committed or flushed before aborting
        mock_session.commit.assert_not_called()
        mock_session.flush.assert_not_called()
    finally:
        app.dependency_overrides.clear()
