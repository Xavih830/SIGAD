"""Argon2id password hashing and JWT token utilities.

Security invariants enforced:
- Argon2id verification runs in a thread (asyncio.to_thread) to avoid blocking the event loop.
- A pre-computed dummy hash is kept in memory so that lookups for non-existent users
  still perform a full Argon2 verification, ensuring constant-time responses.
"""

import asyncio
from datetime import datetime, timedelta, timezone

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
import jwt
from pydantic import SecretStr

from app.core.config import settings
from app.core.constants import (
    ARGON2_MEMORY_COST,
    ARGON2_PARALLELISM,
    ARGON2_TIME_COST,
)


ph = PasswordHasher(
    memory_cost=ARGON2_MEMORY_COST,
    time_cost=ARGON2_TIME_COST,
    parallelism=ARGON2_PARALLELISM,
)

DUMMY_HASH: str = ph.hash("dummy-never-matches-any-real-password")


def hash_password(plain: str) -> str:
    """Hash a plaintext password with Argon2id."""
    return ph.hash(plain)


def _verify_sync(plain: str, hashed: str) -> bool:
    """Synchronous verification — meant to run in a thread."""
    try:
        return ph.verify(hashed, plain)
    except VerifyMismatchError:
        return False


async def verify_password(plain: str, hashed: str) -> bool:
    """Verify a password against a hash without blocking the event loop."""
    return await asyncio.to_thread(_verify_sync, plain, hashed)


async def verify_dummy(plain: str) -> bool:
    """Verify against the dummy hash (constant-time defense for missing users)."""
    return await asyncio.to_thread(_verify_sync, plain, DUMMY_HASH)


def _get_jwt_secret() -> str:
    key = settings.JWT_SECRET_KEY
    return key.get_secret_value() if isinstance(key, SecretStr) else str(key)


def _resolve_secret_string(sec: str | SecretStr) -> str:
    return sec.get_secret_value() if isinstance(sec, SecretStr) else str(sec)


def create_access_token(data: dict) -> str:
    """Create a signed JWT access token."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {**data, "exp": expire, "type": "access"}
    return jwt.encode(to_encode, _get_jwt_secret(), algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(data: dict) -> str:
    """Create a signed JWT refresh token."""
    expire = datetime.now(timezone.utc) + timedelta(days=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode = {**data, "exp": expire, "type": "refresh"}
    return jwt.encode(to_encode, _get_jwt_secret(), algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    """Decode and validate a JWT token."""
    return jwt.decode(token, _get_jwt_secret(), algorithms=[settings.JWT_ALGORITHM])



import hashlib
import hmac
import secrets


def generate_otp_code(length: int = 6) -> str:
    """Generate a cryptographically secure numeric OTP code."""
    digits = "0123456789"
    return "".join(secrets.choice(digits) for _ in range(length))


def compute_otp_hmac(code: str, secret_key: str | SecretStr | None = None) -> str:
    """Compute HMAC-SHA256 digest for an OTP code using the specified or active secret key."""
    raw_key = _resolve_secret_string(secret_key if secret_key is not None else settings.OTP_SECRET_KEY_ACTUAL)
    key = raw_key.encode("utf-8")
    return hmac.new(key, code.encode("utf-8"), hashlib.sha256).hexdigest()


DUMMY_OTP_HMAC: str = compute_otp_hmac("000000", settings.OTP_SECRET_KEY_ACTUAL)


def verify_dummy_otp(code: str = "000000") -> bool:
    """Constant-time dummy OTP verification against fake digest to prevent timing side channels."""
    fake_digest = compute_otp_hmac(code, settings.OTP_SECRET_KEY_ACTUAL)
    return hmac.compare_digest(fake_digest, DUMMY_OTP_HMAC)


def verify_otp_hmac(code: str, stored_hmac: str) -> bool:
    """Verify OTP HMAC digest supporting quarterly key rotation.
    
    1. Compares against active quarterly secret (OTP_SECRET_KEY_ACTUAL).
    2. If mismatch, falls back to previous quarter secret (OTP_SECRET_KEY_ANTERIOR).
    """
    digest_actual = compute_otp_hmac(code, settings.OTP_SECRET_KEY_ACTUAL)
    if hmac.compare_digest(digest_actual, stored_hmac):
        return True

    digest_anterior = compute_otp_hmac(code, settings.OTP_SECRET_KEY_ANTERIOR)
    if hmac.compare_digest(digest_anterior, stored_hmac):
        return True

    return False

