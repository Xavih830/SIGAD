"""Evaluación de las 4 capas de limitación de tasa (IP, identidad, tarpitting, bloqueo)."""

import pytest

from app.core.rate_limit import (
    AccountLockedOut,
    RateLimitExceeded,
    RateLimiter,
)


def test_layer1_ip_rate_limit_login():
    """Layer 1: Max 5 requests per 15 minutes for /login."""
    limiter = RateLimiter(maxsize=100)
    test_ip = "192.168.1.100"

    for _ in range(5):
        limiter.check_ip(test_ip, endpoint="login")
        limiter.record_ip(test_ip, endpoint="login")

    with pytest.raises(RateLimitExceeded, match="Límite de peticiones por IP excedido"):
        limiter.check_ip(test_ip, endpoint="login")


def test_layer1_ip_rate_limit_vinculacion():
    """Layer 1: Max 3 requests per 1 minute for /vinculacion."""
    limiter = RateLimiter(maxsize=100)
    test_ip = "192.168.1.101"

    for _ in range(3):
        limiter.check_ip(test_ip, endpoint="vinculacion")
        limiter.record_ip(test_ip, endpoint="vinculacion")

    with pytest.raises(RateLimitExceeded, match="Límite de peticiones por IP excedido"):
        limiter.check_ip(test_ip, endpoint="vinculacion")


def test_layer2_identity_rate_limit():
    """Layer 2: Max 5 attempts for identity on login, 3 on vinculacion."""
    limiter = RateLimiter(maxsize=100)
    identity = "0926687856"

    for _ in range(3):
        limiter.check_identity(identity, endpoint="vinculacion")
        limiter.record_identity(identity, endpoint="vinculacion")

    with pytest.raises(RateLimitExceeded, match="Límite de intentos para la identidad"):
        limiter.check_identity(identity, endpoint="vinculacion")


@pytest.mark.asyncio
async def test_layer3_tarpitting_burst_delay():
    """Layer 3: Bursts of requests receive progressive delay without outright block."""
    limiter = RateLimiter(maxsize=100)
    test_ip = "10.0.0.50"

    d0 = await limiter.apply_tarpitting(test_ip)
    assert d0 == 0.0

    d1 = await limiter.apply_tarpitting(test_ip)
    assert d1 >= 0.5

    d2 = await limiter.apply_tarpitting(test_ip)
    assert d2 >= d1


def test_layer4_account_lockout():
    """Layer 4: 10 accumulated failures in 1 hour locks the account for 30 minutes."""
    limiter = RateLimiter(maxsize=100)
    identity = "victima@rjseguros.ec"

    assert limiter.is_account_locked(identity) is False

    for _ in range(9):
        limiter.record_failure(identity)
    assert limiter.is_account_locked(identity) is False

    limiter.record_failure(identity)
    assert limiter.is_account_locked(identity) is True

    import asyncio
    with pytest.raises(AccountLockedOut, match="Cuenta bloqueada temporalmente"):
        asyncio.run(limiter.check_all(ip="127.0.0.1", identity=identity, endpoint="login"))

    limiter.record_success(identity)
    assert limiter.is_account_locked(identity) is False


def test_layer1_ip_rate_limit_catalogo():
    """Layer 1: Max 60 requests per 1 minute for catalogo endpoints."""
    limiter = RateLimiter(maxsize=100)
    test_ip = "192.168.1.102"

    for _ in range(60):
        limiter.check_ip(test_ip, endpoint="catalogo")
        limiter.record_ip(test_ip, endpoint="catalogo")

    with pytest.raises(RateLimitExceeded, match="Límite de peticiones por IP excedido"):
        limiter.check_ip(test_ip, endpoint="catalogo")


def test_get_client_ip_resolution():
    """get_client_ip must strictly prioritize X-Real-IP over client host and ignore spoofed headers."""
    from unittest.mock import MagicMock
    from app.api.deps import get_client_ip

    mock_req_caddy = MagicMock()
    mock_req_caddy.headers.get.side_effect = lambda h: "203.0.113.195" if h == "x-real-ip" else None
    assert get_client_ip(mock_req_caddy) == "203.0.113.195"

    mock_req_direct = MagicMock()
    mock_req_direct.headers.get.return_value = None
    mock_req_direct.client.host = "192.168.1.50"
    assert get_client_ip(mock_req_direct) == "192.168.1.50"

    mock_req_none = MagicMock()
    mock_req_none.headers.get.return_value = None
    mock_req_none.client = None
    assert get_client_ip(mock_req_none) == "127.0.0.1"

