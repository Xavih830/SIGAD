"""TEST 5: Uniform error responses on login failure.

Verifies that the error message returned is exactly the same whether:
- The user does not exist at all
- The user exists but the password is wrong
This prevents user enumeration attacks.
"""

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.security import hash_password
from app.main import app
from app.models.usuario import RolEnum


@pytest.mark.asyncio
async def test_uniform_error_responses():
    """Error responses must be identical for non-existent user vs wrong password."""
    from app.db.session import get_db

    # ── Scenario A: User does NOT exist ──────────────────────────
    mock_result_none = MagicMock()
    mock_result_none.scalar_one_or_none.return_value = None

    mock_session_a = AsyncMock()
    mock_session_a.execute.return_value = mock_result_none
    mock_session_a.commit = AsyncMock()

    async def fake_db_no_user():
        yield mock_session_a

    app.dependency_overrides[get_db] = fake_db_no_user

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp_no_user = await client.post(
            "/api/v1/auth/login",
            json={"identificador": "nonexistent@example.com", "password": "anything"},
        )

    # ── Scenario B: User exists but password is wrong ────────────
    fake_user = MagicMock()
    fake_user.id = uuid.uuid4()
    fake_user.email = "admin@sigad.ec"
    fake_user.password_hash = hash_password("CorrectPassword")
    fake_user.nombre = "Admin"
    fake_user.rol = RolEnum.ADMIN
    fake_user.activo = True

    mock_result_found = MagicMock()
    mock_result_found.scalar_one_or_none.return_value = fake_user

    mock_session_b = AsyncMock()
    mock_session_b.execute.return_value = mock_result_found
    mock_session_b.commit = AsyncMock()

    async def fake_db_wrong_pw():
        yield mock_session_b

    app.dependency_overrides[get_db] = fake_db_wrong_pw

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp_wrong_pw = await client.post(
            "/api/v1/auth/login",
            json={"identificador": "admin@sigad.ec", "password": "WrongPassword"},
        )

    app.dependency_overrides.clear()

    # ── Assertions ───────────────────────────────────────────────
    assert resp_no_user.status_code == 401, f"Non-existent user should return 401, got {resp_no_user.status_code}"
    assert resp_wrong_pw.status_code == 401, f"Wrong password should return 401, got {resp_wrong_pw.status_code}"

    # The critical check: both responses have identical error messages
    msg_no_user = resp_no_user.json()["detail"]
    msg_wrong_pw = resp_wrong_pw.json()["detail"]
    assert msg_no_user == msg_wrong_pw, (
        f"Error messages must be identical to prevent user enumeration. "
        f"Got: '{msg_no_user}' vs '{msg_wrong_pw}'"
    )
