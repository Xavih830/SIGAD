"""Test que certifica que las constantes canónicas existen y cumplen las restricciones de diseño."""

from decimal import Decimal
from app.core import constants


def test_constantes_limites_almacenamiento():
    """Verifica que los límites de subida coincidan exactamente con la especificación de 15MB y 10 páginas."""
    assert constants.MAX_DOCUMENT_SIZE_BYTES == 15 * 1024 * 1024
    assert constants.MAX_PDF_PAGES_PERMITTED == 10
    assert "application/pdf" in constants.PERMITTED_MIME_TYPES
    assert "image/jpeg" in constants.PERMITTED_MIME_TYPES


def test_constantes_ocr_y_timeouts():
    """Verifica los umbrales de extracción a 200 DPI y 120s de timeout."""
    assert constants.OCR_PROCESS_TIMEOUT_SECONDS == 120
    assert constants.TESSERACT_STANDARD_DPI == 200
    assert constants.GATE1_TEXT_LENGTH_THRESHOLD == 50
    assert constants.MAX_OCR_FAILED_ATTEMPTS == 3
    assert constants.WATCHDOG_STALE_MINUTES == 5


def test_constantes_seguridad_otp():
    """Verifica la parametrización de seguridad de OTP y contraseñas."""
    assert constants.OTP_LENGTH == 6
    assert constants.MAX_FAILED_OTP_ATTEMPTS == 3
    assert constants.OTP_EXPIRATION_MINUTES == 15
    assert constants.MIN_PASSWORD_LENGTH == 12


def test_constantes_rate_limit_y_polizas():
    """Verifica límites de rate limit y vigencia de pólizas."""
    assert constants.RATE_LIMIT_LOGIN_MAX_REQUESTS == 5
    assert constants.RATE_LIMIT_LOGIN_WINDOW_SECONDS == 900
    assert constants.RATE_LIMIT_LOCKOUT_MAX_FAILS == 10
    assert constants.RATE_LIMIT_LOCKOUT_WINDOW_SECONDS == 3600
    assert constants.RATE_LIMIT_LOCKOUT_DURATION_SECONDS == 1800
    assert constants.RATE_LIMIT_TARPIT_BURST_THRESHOLD == 2
    assert constants.MAX_VIGENCIA_ANIOS == 5
    assert constants.DIAS_ALERTA_POR_VENCER == 30
