"""Logging filter for source-level PII redaction (emails, cédulas/RUC, placas, secrets)."""

import logging
import re


class PIIRedactionFilter(logging.Filter):
    """Logging filter that redacts sensitive PII fields from log messages and arguments."""

    RUC_REGEX = re.compile(r"\b\d{13}\b")
    CEDULA_REGEX = re.compile(r"\b\d{10}\b")
    EMAIL_REGEX = re.compile(r"\b[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+\b")
    PLACA_REGEX = re.compile(r"\b[A-Z]{2,3}-\d{3,4}[A-Z]?\b")
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
        text = cls.RUC_REGEX.sub("[REDACTED_RUC]", text)
        text = cls.CEDULA_REGEX.sub("[REDACTED_CEDULA]", text)
        text = cls.PLACA_REGEX.sub("[REDACTED_PLACA]", text)

        return text

    def filter(self, record: logging.LogRecord) -> bool:
        rendered_msg = record.getMessage()
        record.msg = self.redact(rendered_msg)
        record.args = None
        return True


def install_pii_redaction_filter() -> None:
    """Attach PIIRedactionFilter to root logger and uvicorn handlers idempotently."""
    redactor = PIIRedactionFilter()
    for logger_name in ("", "uvicorn", "uvicorn.access", "uvicorn.error", "sigad"):
        target_logger = logging.getLogger(logger_name)
        if not any(isinstance(f, PIIRedactionFilter) for f in target_logger.filters):
            target_logger.addFilter(redactor)
        for handler in target_logger.handlers:
            if not any(isinstance(f, PIIRedactionFilter) for f in handler.filters):
                handler.addFilter(redactor)
