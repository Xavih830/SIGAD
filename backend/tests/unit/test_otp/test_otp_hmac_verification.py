"""TEST 18: Verificación de OTP vía HMAC-SHA256 con soporte para clave actual y anterior."""

from app.core.config import settings
from app.core.security import compute_otp_hmac, verify_otp_hmac


def test_otp_hmac_verification_with_actual_key():
    """OTP generated with active quarterly key should verify successfully."""
    codigo = "849201"
    hmac_actual = compute_otp_hmac(codigo, settings.OTP_SECRET_KEY_ACTUAL)

    # Must verify as True
    assert verify_otp_hmac(codigo, hmac_actual) is True


def test_otp_hmac_verification_with_anterior_key():
    """OTP generated during key rotation transition (with anterior key) should still verify."""
    codigo = "392018"
    hmac_anterior = compute_otp_hmac(codigo, settings.OTP_SECRET_KEY_ANTERIOR)

    # Must verify as True (rotation grace window)
    assert verify_otp_hmac(codigo, hmac_anterior) is True


def test_otp_hmac_verification_wrong_code():
    """An incorrect OTP code must fail verification."""
    codigo_correcto = "123456"
    codigo_incorrecto = "654321"
    hmac_digest = compute_otp_hmac(codigo_correcto, settings.OTP_SECRET_KEY_ACTUAL)

    assert verify_otp_hmac(codigo_incorrecto, hmac_digest) is False


def test_otp_hmac_verification_tampered_key():
    """An OTP generated with an unrelated secret key must be rejected."""
    codigo = "555888"
    hmac_malicioso = compute_otp_hmac(codigo, "unrelated-attacker-key")

    assert verify_otp_hmac(codigo, hmac_malicioso) is False
