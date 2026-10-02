"""Integration test verifying real SMTP dispatch and OTP capture against Mailpit."""

import os
import uuid
import httpx
import pytest
from app.services.smtp_service import smtp_service
from tests.factories import (
    CLIENTE_NAME,
    DEFAULT_OTP,
    TEST_MAILPIT_HOST,
    TEST_MAILPIT_HTTP_PORT,
)

pytestmark = pytest.mark.asyncio


async def test_smtp_mailpit_delivery_and_otp_matching():
    """Verify that an email sent via SMTP arrives in Mailpit and contains the exact OTP."""
    mailpit_api_url = f"http://{TEST_MAILPIT_HOST}:{TEST_MAILPIT_HTTP_PORT}/api/v1/messages"

    test_otp = DEFAULT_OTP
    test_client_name = CLIENTE_NAME
    test_email = f"carlos.{uuid.uuid4().hex[:6]}@cliente.ec"

    # Enviar correo mediante el servicio real
    delivered = await smtp_service.send_otp_email(
        destinatario=test_email,
        codigo_otp=test_otp,
        nombres=test_client_name,
        smtp_host=TEST_MAILPIT_HOST,
    )
    assert delivered is True, "El envío SMTP debe ser exitoso hacia Mailpit."

    # Consultar la API REST de Mailpit para verificar recepción
    async with httpx.AsyncClient() as client:
        resp = await client.get(mailpit_api_url)
        assert resp.status_code == 200, "Mailpit API debe responder HTTP 200."
        data = resp.json()
        messages = data.get("messages", [])

        # Buscar el mensaje destinado a test_email
        matching_msg = next((m for m in messages if test_email in m.get("To", [{}])[0].get("Address", "")), None)
        assert matching_msg is not None, f"Mailpit debe haber capturado el correo enviado a {test_email}."

        msg_id = matching_msg["ID"]
        msg_detail_resp = await client.get(f"{mailpit_api_url.rstrip('/messages')}/message/{msg_id}")
        assert msg_detail_resp.status_code == 200
        msg_detail = msg_detail_resp.json()

        # Validar cuerpo del mensaje
        body_text = msg_detail.get("Text", "")
        assert test_otp in body_text, f"El cuerpo del mensaje debe contener el OTP {test_otp}."
        assert test_client_name in body_text, "El cuerpo del mensaje debe saludar al cliente."
