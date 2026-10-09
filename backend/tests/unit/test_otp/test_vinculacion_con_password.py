"""Validación de complejidad de contraseña (>= 12 caracteres, 4 clases)."""

import pytest
from pydantic import ValidationError

from app.schemas.cliente import VinculacionRequest, validar_complejidad_password
from tests.factories import (
    INVALID_PASSWORDS,
    MSG_PASSWORD_MIN_LENGTH,
    MSG_PASSWORD_MISMATCH,
    MSG_PASSWORD_REQUIRES_DIGIT,
    MSG_PASSWORD_REQUIRES_LOWER,
    MSG_PASSWORD_REQUIRES_SPECIAL,
    MSG_PASSWORD_REQUIRES_UPPER,
    VALID_PASSWORDS,
    vinculacion_payload,
)


def test_password_complexity_valid():
    """Passwords meeting all 4 classes and >= 12 chars should be accepted."""
    for pwd in VALID_PASSWORDS:
        assert validar_complejidad_password(pwd) == pwd


def test_password_too_short():
    """Passwords shorter than 12 characters must be rejected."""
    with pytest.raises(ValueError, match=MSG_PASSWORD_MIN_LENGTH):
        validar_complejidad_password(INVALID_PASSWORDS["too_short"])


def test_password_missing_uppercase():
    """Passwords without uppercase letters must be rejected."""
    with pytest.raises(ValueError, match=MSG_PASSWORD_REQUIRES_UPPER):
        validar_complejidad_password(INVALID_PASSWORDS["missing_upper"])


def test_password_missing_lowercase():
    """Passwords without lowercase letters must be rejected."""
    with pytest.raises(ValueError, match=MSG_PASSWORD_REQUIRES_LOWER):
        validar_complejidad_password(INVALID_PASSWORDS["missing_lower"])


def test_password_missing_digit():
    """Passwords without numbers must be rejected."""
    with pytest.raises(ValueError, match=MSG_PASSWORD_REQUIRES_DIGIT):
        validar_complejidad_password(INVALID_PASSWORDS["missing_digit"])


def test_password_missing_special_char():
    """Passwords without special characters must be rejected."""
    with pytest.raises(ValueError, match=MSG_PASSWORD_REQUIRES_SPECIAL):
        validar_complejidad_password(INVALID_PASSWORDS["missing_special"])


def test_vinculacion_request_schema_validation():
    """VinculacionRequest schema rejects weak passwords and mismatched confirmation."""
    payload = vinculacion_payload()
    req = VinculacionRequest(**payload)
    assert req.cedula == payload["cedula"]
    assert req.codigo_otp == payload["codigo_otp"]

    with pytest.raises(ValidationError, match=MSG_PASSWORD_MISMATCH):
        VinculacionRequest(
            **vinculacion_payload(password_confirmacion="DifferentPassword123*")
        )
