"""Verificación estructural de tiempo constante ante cédulas no registradas en vinculación."""

import ast
import inspect
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.api.v1.endpoints import auth as auth_module
from app.core import security
from app.core.rate_limit import rate_limiter
from app.db.session import get_db
from app.main import app
from tests.factories import vinculacion_payload


def test_constant_time_vinculacion_structural_ast():
    """Structurally verify constant-time defense mechanisms exist in vinculación endpoint."""
    assert hasattr(security, "DUMMY_HASH"), "security module must define DUMMY_HASH"
    assert hasattr(security, "DUMMY_OTP_HMAC"), "security module must define DUMMY_OTP_HMAC"

    assert hasattr(security, "verify_dummy"), "security module must define verify_dummy"
    assert hasattr(security, "verify_dummy_otp"), "security module must define verify_dummy_otp"

    source = inspect.getsource(auth_module.vincular_cliente)
    tree = ast.parse(source)

    called_functions = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                called_functions.add(node.func.id)
            elif isinstance(node.func, ast.Attribute):
                called_functions.add(node.func.attr)

    assert "verify_dummy" in called_functions or "verify_dummy_otp" in called_functions, (
        "Endpoint vincular_cliente must invoke verify_dummy or verify_dummy_otp to prevent timing side channels"
    )


@pytest.mark.asyncio
async def test_constant_time_vinculacion_functional_nonexistent_cedula():
    """Functional verification: requesting vinculacion for a non-existent cédula returns 400 without crashing."""
    rate_limiter.reset()

    mock_session = AsyncMock()
    res_none = MagicMock()
    res_none.scalar_one_or_none.return_value = None
    mock_session.execute.return_value = res_none

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

        assert response.status_code == 400
        assert "Código de vinculación inválido o expirado." in response.json()["detail"]
    finally:
        app.dependency_overrides.clear()
