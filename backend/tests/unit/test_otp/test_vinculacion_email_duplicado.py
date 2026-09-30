"""TEST 17: Detección de colisión de email lanzando EmailDuplicadoException (HTTP 409)."""

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.exceptions import EmailDuplicadoException
from app.core.rate_limit import rate_limiter
from app.db.session import get_db
from app.main import app
from app.models.cliente import Cliente
from app.models.usuario import Usuario


@pytest.mark.asyncio
async def test_vinculacion_email_duplicado():
    """When target email is already registered in usuarios, abort immediately with EmailDuplicadoException (HTTP 409)."""
    rate_limiter.reset()

    fake_cliente = MagicMock(spec=Cliente)
    fake_cliente.id = uuid.uuid4()
    fake_cliente.identificacion = "0926687856"
    fake_cliente.nombres = "Juan Fernando Perez"
    fake_cliente.email = "duplicado@cliente.ec"

    fake_usuario = MagicMock(spec=Usuario)
    fake_usuario.id = uuid.uuid4()
    fake_usuario.email = "duplicado@cliente.ec"

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
                json={
                    "cedula": "0926687856",
                    "codigo_otp": "123456",
                    "password": "PasswordSeguro2026*",
                    "password_confirmacion": "PasswordSeguro2026*",
                },
            )

        assert response.status_code == 409, f"Expected 409, got {response.status_code}: {response.text}"
        data = response.json()
        assert data["detail"] == "El correo electrónico ya se encuentra registrado"

        # Verify that no changes were committed or flushed before aborting
        mock_session.commit.assert_not_called()
        mock_session.flush.assert_not_called()
    finally:
        app.dependency_overrides.clear()
