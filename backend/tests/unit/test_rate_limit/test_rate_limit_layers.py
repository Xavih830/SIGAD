"""TEST 21: Evaluación de las 4 capas de limitación de tasa (IP, identidad, tarpitting, bloqueo)."""

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

    # First 5 attempts should pass
    for _ in range(5):
        limiter.check_ip(test_ip, endpoint="login")
        limiter.record_ip(test_ip, endpoint="login")

    # 6th attempt must be rejected
    with pytest.raises(RateLimitExceeded, match="Límite de peticiones por IP excedido"):
        limiter.check_ip(test_ip, endpoint="login")


def test_layer1_ip_rate_limit_vinculacion():
    """Layer 1: Max 3 requests per 1 minute for /vinculacion."""
    limiter = RateLimiter(maxsize=100)
    test_ip = "192.168.1.101"

    # First 3 attempts pass
    for _ in range(3):
        limiter.check_ip(test_ip, endpoint="vinculacion")
        limiter.record_ip(test_ip, endpoint="vinculacion")

    # 4th attempt rejected
    with pytest.raises(RateLimitExceeded, match="Límite de peticiones por IP excedido"):
        limiter.check_ip(test_ip, endpoint="vinculacion")


def test_layer2_identity_rate_limit():
    """Layer 2: Max 5 attempts for identity on login, 3 on vinculacion."""
    limiter = RateLimiter(maxsize=100)
    identity = "0926687856"

    # 3 attempts for vinculacion pass
    for _ in range(3):
        limiter.check_identity(identity, endpoint="vinculacion")
        limiter.record_identity(identity, endpoint="vinculacion")

    # 4th attempt rejected
    with pytest.raises(RateLimitExceeded, match="Límite de intentos para la identidad"):
        limiter.check_identity(identity, endpoint="vinculacion")


@pytest.mark.asyncio
async def test_layer3_tarpitting_burst_delay():
    """Layer 3: Bursts of requests receive progressive delay without outright block."""
    limiter = RateLimiter(maxsize=100)
    test_ip = "10.0.0.50"

    # Initially 0 delay
    d0 = await limiter.apply_tarpitting(test_ip)
    assert d0 == 0.0

    # 2nd immediate attempt: threshold reached
    d1 = await limiter.apply_tarpitting(test_ip)
    assert d1 >= 0.5

    # 3rd immediate attempt: delay grows
    d2 = await limiter.apply_tarpitting(test_ip)
    assert d2 >= d1


def test_layer4_account_lockout():
    """Layer 4: 10 accumulated failures in 1 hour locks the account for 30 minutes."""
    limiter = RateLimiter(maxsize=100)
    identity = "victima@rjseguros.ec"

    assert limiter.is_account_locked(identity) is False

    # Record 9 failed attempts -> still unlocked
    for _ in range(9):
        limiter.record_failure(identity)
    assert limiter.is_account_locked(identity) is False

    # 10th failure -> locks account
    limiter.record_failure(identity)
    assert limiter.is_account_locked(identity) is True

    # Check consolidated raises AccountLockedOut
    import asyncio
    with pytest.raises(AccountLockedOut, match="Cuenta bloqueada temporalmente"):
        asyncio.run(limiter.check_all(ip="127.0.0.1", identity=identity, endpoint="login"))

    # Successful login resets lockout
    limiter.record_success(identity)
    assert limiter.is_account_locked(identity) is False
