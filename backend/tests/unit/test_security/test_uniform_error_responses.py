"""Uniform error responses on login failure.

Verifies that the error message returned is exactly the same whether:
- The user does not exist at all
- The user exists but the password is wrong
This prevents user enumeration attacks.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.main import app
from tests.factories import (
    ADMIN_EMAIL,
    create_mock_admin_user,
    login_payload,
)


@pytest.mark.asyncio
async def test_uniform_error_responses():
    """Error responses must be identical for non-existent user vs wrong password."""
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
            json=login_payload("nonexistent@example.com", "anything"),
        )

    fake_user = create_mock_admin_user(password="CorrectPassword")

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
            json=login_payload(ADMIN_EMAIL, "WrongPassword"),
        )

    app.dependency_overrides.clear()

    assert resp_no_user.status_code == 401, f"Non-existent user should return 401, got {resp_no_user.status_code}"
    assert resp_wrong_pw.status_code == 401, f"Wrong password should return 401, got {resp_wrong_pw.status_code}"

    msg_no_user = resp_no_user.json()["detail"]
    msg_wrong_pw = resp_wrong_pw.json()["detail"]
    assert msg_no_user == msg_wrong_pw, (
        f"Error messages must be identical to prevent user enumeration. "
        f"Got: '{msg_no_user}' vs '{msg_wrong_pw}'"
    )
