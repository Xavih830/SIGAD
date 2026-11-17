"""Pruebas de ofuscación y redacción de PII en logs (emails, cédulas, RUC, placas, secretos)."""

import io
import logging

from app.core.logging_filter import PIIRedactionFilter, install_pii_redaction_filter


def test_redact_ecuadorian_cedula_and_ruc():
    """Verify that 10-digit cédulas and 13-digit RUC numbers are redacted."""
    raw = "Failed login cedula 0923456789 and RUC 1790012345001."
    redacted = PIIRedactionFilter.redact(raw)
    assert "0923456789" not in redacted
    assert "1790012345001" not in redacted
    assert "[REDACTED_CEDULA]" in redacted
    assert "[REDACTED_RUC]" in redacted


def test_redact_email_address():
    """Verify that email addresses are masked."""
    raw = "User user.test+demo@seguros-rj.com.ec requested password reset."
    redacted = PIIRedactionFilter.redact(raw)
    assert "user.test+demo@seguros-rj.com.ec" not in redacted
    assert "[REDACTED_EMAIL]" in redacted


def test_redact_vehicle_plates():
    """Verify that Ecuadorian auto and moto plates are masked."""
    raw = "Poliza emitida para placa PBA-1234 y moto AB-123C."
    redacted = PIIRedactionFilter.redact(raw)
    assert "PBA-1234" not in redacted
    assert "AB-123C" not in redacted
    assert redacted.count("[REDACTED_PLACA]") == 2


def test_redact_passwords_and_secrets():
    """Verify that JSON-like or key-value passwords are redacted."""
    raw_json = '{"email": "agent@rj.ec", "contrasenia": "SuperSecretP@ss123"}'
    redacted_json = PIIRedactionFilter.redact(raw_json)
    assert "SuperSecretP@ss123" not in redacted_json
    assert "[REDACTED_SECRET]" in redacted_json

    raw_token = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig"
    redacted_token = PIIRedactionFilter.redact(raw_token)
    assert "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" not in redacted_token
    assert "[REDACTED_TOKEN]" in redacted_token


def test_pii_logging_filter_in_standard_logger():
    """Verify that a standard logging.Logger equipped with PIIRedactionFilter scrubs records."""
    log_stream = io.StringIO()
    handler = logging.StreamHandler(log_stream)
    handler.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
    handler.addFilter(PIIRedactionFilter())

    logger = logging.getLogger("sigad.security.test_logger")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    logger.addHandler(handler)

    logger.info(
        "Vinculacion OTP: cliente=%s ruc=%s email=%s placa=%s clave_temp='%s'",
        "1710034065",
        "1710034065001",
        "juan.perez@example.com",
        "PBA-1234",
        "TempPassword999",
    )

    output = log_stream.getvalue()
    assert "1710034065" not in output
    assert "1710034065001" not in output
    assert "juan.perez@example.com" not in output
    assert "PBA-1234" not in output
    assert "TempPassword999" not in output
    assert "[REDACTED_CEDULA]" in output
    assert "[REDACTED_RUC]" in output
    assert "[REDACTED_EMAIL]" in output
    assert "[REDACTED_PLACA]" in output


def test_non_pii_operational_ids_preserved():
    """Verify that non-PII numeric operational IDs are NOT masked."""
    log_msg = "Consulta de catalogo completada con total=42 en 12ms."
    redacted = PIIRedactionFilter.redact(log_msg)
    assert "42" in redacted
    install_pii_redaction_filter()
