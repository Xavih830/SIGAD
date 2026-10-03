"""SMTP Service — Asynchronous corporate backup channel for OTP dispatch via smtplib."""

import asyncio
from email.message import EmailMessage
import logging
import os
import smtplib
from typing import Optional

from app.core.config import settings

logger = logging.getLogger("sigad.smtp")


class SMTPService:
    """Asynchronous corporate email dispatcher for OTP codes as a backup channel."""

    def __init__(
        self,
        smtp_host: Optional[str] = None,
        smtp_port: Optional[int] = None,
        from_email: Optional[str] = None,
        smtp_user: Optional[str] = None,
        smtp_password: Optional[str] = None,
        use_tls: Optional[bool] = None,
    ) -> None:
        self.smtp_host = smtp_host if smtp_host is not None else settings.SMTP_HOST
        self.smtp_port = smtp_port if smtp_port is not None else settings.SMTP_PORT
        self.from_email = from_email if from_email is not None else settings.SMTP_FROM_EMAIL
        self.smtp_user = smtp_user if smtp_user is not None else settings.SMTP_USER
        raw_password = smtp_password if smtp_password is not None else settings.SMTP_PASSWORD
        self.smtp_password = raw_password.get_secret_value() if hasattr(raw_password, "get_secret_value") else str(raw_password)
        self.use_tls = use_tls if use_tls is not None else settings.SMTP_USE_TLS

    def _send_sync(
        self,
        to_email: str,
        subject: str,
        content: str,
        host: Optional[str] = None,
        port: Optional[int] = None,
    ) -> None:
        """Synchronous SMTP connection executed in a worker thread to prevent event loop blocking."""
        msg = EmailMessage()
        msg["Subject"] = subject
        msg["From"] = self.from_email
        msg["To"] = to_email
        msg.set_content(content)

        target_host = host if host is not None else self.smtp_host
        target_port = port if port is not None else self.smtp_port

        with smtplib.SMTP(target_host, target_port, timeout=10.0) as server:
            if self.use_tls:
                server.starttls()
            if self.smtp_user and self.smtp_password:
                server.login(self.smtp_user, self.smtp_password)
            server.send_message(msg)

    async def send_otp_email(
        self,
        destinatario: str,
        codigo_otp: str,
        nombres: str,
        smtp_host: Optional[str] = None,
        smtp_port: Optional[int] = None,
    ) -> bool:
        """Asynchronously dispatch OTP code email as secondary backup channel.
        
        Fail-safe: never raises unhandled exceptions to avoid breaking client creation.
        """
        if not destinatario or "@" not in destinatario:
            logger.warning("smtp_dispatch_skipped reason=invalid_recipient recipient=%s", destinatario)
            return False

        subject = "Código de Vinculación Móvil - SIGAD RJ Seguros"
        body = (
            f"Estimado/a {nombres},\n\n"
            f"Su código de vinculación para la aplicación móvil SIGAD es: {codigo_otp}\n\n"
            f"Este código es de uso personal y expira en 15 minutos.\n"
            f"Si usted no solicitó este código, comuníquese de inmediato con RJ Seguros.\n\n"
            f"Atentamente,\n"
            f"Equipo de Seguridad de RJ Seguros"
        )

        try:
            await asyncio.to_thread(self._send_sync, destinatario, subject, body, smtp_host, smtp_port)
            logger.info("smtp_backup_dispatched recipient=%s host=%s:%d", destinatario, smtp_host or self.smtp_host, smtp_port or self.smtp_port)
            return True
        except Exception as exc:
            logger.error("smtp_backup_failed recipient=%s error=%s", destinatario, str(exc))
            return False


# Global singleton instance configured via environment
smtp_service = SMTPService()
