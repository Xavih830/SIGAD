"""TEST 16: Validación de complejidad de contraseña (>= 12 caracteres, 4 clases)."""

import pytest
from pydantic import ValidationError

from app.schemas.cliente import VinculacionRequest, validar_complejidad_password


def test_password_complexity_valid():
    """Passwords meeting all 4 classes and >= 12 chars should be accepted."""
    valid_passwords = [
        "PasswordSeguro2026*",
        "Admin#SIGAD2024!",
        "Compl3x!P@ssword2026",
        "Abcdef123456!@",
    ]
    for pwd in valid_passwords:
        assert validar_complejidad_password(pwd) == pwd


def test_password_too_short():
    """Passwords shorter than 12 characters must be rejected."""
    with pytest.raises(ValueError, match="al menos 12 caracteres"):
        validar_complejidad_password("Short1!Aa")


def test_password_missing_uppercase():
    """Passwords without uppercase letters must be rejected."""
    with pytest.raises(ValueError, match="letra mayúscula"):
        validar_complejidad_password("passwordseguro2026*")


def test_password_missing_lowercase():
    """Passwords without lowercase letters must be rejected."""
    with pytest.raises(ValueError, match="letra minúscula"):
        validar_complejidad_password("PASSWORDSEGURO2026*")


def test_password_missing_digit():
    """Passwords without numbers must be rejected."""
    with pytest.raises(ValueError, match="al menos un número"):
        validar_complejidad_password("PasswordSeguroSinNumero*")


def test_password_missing_special_char():
    """Passwords without special characters must be rejected."""
    with pytest.raises(ValueError, match="carácter especial"):
        validar_complejidad_password("PasswordSeguro2026")


def test_vinculacion_request_schema_validation():
    """VinculacionRequest schema rejects weak passwords and mismatched confirmation."""
    # Valid payload
    payload = {
        "cedula": "0926687856",
        "codigo_otp": "123456",
        "password": "PasswordSeguro2026*",
        "password_confirmacion": "PasswordSeguro2026*",
    }
    req = VinculacionRequest(**payload)
    assert req.cedula == "0926687856"
    assert req.codigo_otp == "123456"

    # Mismatched confirmation
    with pytest.raises(ValidationError, match="confirmación de la contraseña no coincide"):
        VinculacionRequest(
            cedula="0926687856",
            codigo_otp="123456",
            password="PasswordSeguro2026*",
            password_confirmacion="DifferentPassword123*",
        )
