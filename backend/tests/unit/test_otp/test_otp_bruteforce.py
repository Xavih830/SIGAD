"""Bloqueo e invalidación forzosa del OTP tras 3 intentos fallidos consecutivos."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock
import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.config import settings
from app.core.rate_limit import rate_limiter
from app.core.security import compute_otp_hmac
from app.db.session import get_db
from app.main import app
from app.models.codigo_vinculacion import CodigoVinculacion
from tests.factories import (
    CLIENTE_PASSWORD,
    create_mock_cliente,
    vinculacion_payload,
)


@pytest.mark.asyncio
async def test_otp_bruteforce_invalidates_at_third_failed_attempt():
    """Verify that 3 consecutive failed OTP attempts immediately mark the code as consumido=True."""
    rate_limiter.reset()

    fake_cliente = create_mock_cliente(nombres="Carlos Mendoza", email="carlos@test.ec")

    real_otp = "654321"
    real_hmac = compute_otp_hmac(real_otp, settings.OTP_SECRET_KEY_ACTUAL)

    codigo_obj = CodigoVinculacion(
        id=uuid.uuid4(),
        cliente_id=fake_cliente.id,
        codigo_hmac=real_hmac,
        expira_en=datetime.now(timezone.utc) + timedelta(minutes=15),
        consumido=False,
        intentos_fallidos=0,
    )

    mock_session = AsyncMock()

    res_cliente = MagicMock()
    res_cliente.scalar_one_or_none.return_value = fake_cliente

    res_user = MagicMock()
    res_user.scalar_one_or_none.return_value = None

    res_otp = MagicMock()
    res_otp.scalar_one_or_none.return_value = codigo_obj

    mock_session.execute.side_effect = [
        res_cliente, res_user, res_otp,
        res_cliente, res_user, res_otp,
        res_cliente, res_user, res_otp,
    ]
    mock_session.commit = AsyncMock()

    async def fake_get_db():
        yield mock_session

    app.dependency_overrides.clear()
    app.dependency_overrides[get_db] = fake_get_db

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            r1 = await client.post(
                "/api/v1/auth/vinculacion",
                json=vinculacion_payload(
                    cedula=fake_cliente.identificacion,
                    codigo_otp="000001",
                    password=CLIENTE_PASSWORD,
                ),
            )
            assert r1.status_code == 400
            assert codigo_obj.intentos_fallidos == 1
            assert codigo_obj.consumido is False

            r2 = await client.post(
                "/api/v1/auth/vinculacion",
                json=vinculacion_payload(
                    cedula=fake_cliente.identificacion,
                    codigo_otp="000002",
                    password=CLIENTE_PASSWORD,
                ),
            )
            assert r2.status_code == 400
            assert codigo_obj.intentos_fallidos == 2
            assert codigo_obj.consumido is False

            r3 = await client.post(
                "/api/v1/auth/vinculacion",
                json=vinculacion_payload(
                    cedula=fake_cliente.identificacion,
                    codigo_otp="000003",
                    password=CLIENTE_PASSWORD,
                ),
            )
            assert r3.status_code == 400
            assert codigo_obj.intentos_fallidos == 3
            assert codigo_obj.consumido is True, "El OTP debe estar consumido=True tras el 3er intento fallido"

    finally:
        app.dependency_overrides.clear()
