"""Pruebas de ofuscación y redacción de PII en logs."""

import io
import logging
import re
from typing import Any


class PIIRedactionFilter(logging.Filter):
    """Logging filter that redacts sensitive PII fields from log messages and arguments."""

    CEDULA_REGEX = re.compile(r"\b\d{10}\b")
    EMAIL_REGEX = re.compile(r"\b[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+\b")
    PASSWORD_REGEX = re.compile(
        r"""(?i)(["']?(?:password|contrasenia|token|secret|clave|clave_temp)["']?\s*[:=]\s*["']?)([^"'\s,]+)(["']?)"""
    )
    BEARER_REGEX = re.compile(r"""(?i)(Bearer\s+)[A-Za-z0-9\-_.]+""")

    @classmethod
    def redact(cls, text: str) -> str:
        """Apply sequential redaction regexes to sanitize input string."""
        if not isinstance(text, str):
            text = str(text)

        text = cls.PASSWORD_REGEX.sub(r"\1[REDACTED_SECRET]\3", text)
        text = cls.BEARER_REGEX.sub(r"\1[REDACTED_TOKEN]", text)
        text = cls.EMAIL_REGEX.sub("[REDACTED_EMAIL]", text)
        text = cls.CEDULA_REGEX.sub("[REDACTED_CEDULA]", text)

        return text

    def filter(self, record: logging.LogRecord) -> bool:
        rendered_msg = record.getMessage()
        record.msg = self.redact(rendered_msg)
        record.args = None
        return True


def test_redact_ecuadorian_cedula():
    """Verify that 10-digit Ecuadorian IDs are redacted."""
    raw = "Failed login attempt for cedula 0923456789 on mobile client."
    redacted = PIIRedactionFilter.redact(raw)
    assert "0923456789" not in redacted
    assert "[REDACTED_CEDULA]" in redacted


def test_redact_email_address():
    """Verify that email addresses are masked."""
    raw = "User user.test+demo@seguros-rj.com.ec requested password reset."
    redacted = PIIRedactionFilter.redact(raw)
    assert "user.test+demo@seguros-rj.com.ec" not in redacted
    assert "[REDACTED_EMAIL]" in redacted


def test_redact_passwords_and_secrets():
    """Verify that JSON-like or key-value passwords are redacted."""
    raw_json = '{"email": "agent@rj.ec", "contrasenia": "SuperSecretP@ss123"}'
    redacted_json = PIIRedactionFilter.redact(raw_json)
    assert "SuperSecretP@ss123" not in redacted_json
    assert "[REDACTED_SECRET]" in redacted_json

    raw_token = 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig'
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
        "Vinculacion OTP: cliente=%s con email=%s clave_temp='%s'",
        "1710034065",
        "juan.perez@example.com",
        "TempPassword999",
    )

    output = log_stream.getvalue()
    assert "1710034065" not in output
    assert "juan.perez@example.com" not in output
    assert "TempPassword999" not in output
    assert "[REDACTED_CEDULA]" in output
    assert "[REDACTED_EMAIL]" in output


def test_non_pii_fields_preserved():
    """Verify that non-PII operational identifiers are NOT improperly masked."""
    plate_log = "Poliza emitida para placa PBA-1234 con ID de poliza 42."
    redacted = PIIRedactionFilter.redact(plate_log)
    assert "PBA-1234" in redacted
    assert "42" in redacted
