"""Full E2E Multiverse Test Suite — 0 to 100% verification across all user roles.

Follows the canonical SIGAD Testing Architecture:
- Object Mother & Factory Pattern (TestFixtures / TestFactories / ScenarioBundle).
- Canonical payloads (login_payload, taller_payload, asistencia_payload, cliente_payload, vehiculo_payload, poliza_payload, vinculacion_payload).
- Zero magic numbers & zero scattered literals (app.core.constants & tests.factories.fixtures).
- Fully scoped HTTP clients (make_client).
- Live components without mocks: Mailpit SMTP (:1025) & HTTP API (:8025), Scheduler, Anti-BOLA, Anti-IDOR.
"""

import asyncio
from datetime import date, timedelta
from decimal import Decimal
import os
import uuid

import httpx
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import MAX_FAILED_OTP_ATTEMPTS, MIN_CUOTAS_POLIZA
from app.core.rate_limit import rate_limiter
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.codigo_vinculacion import CodigoVinculacion
from app.workers.scheduler import ejecutar_transiciones_polizas
from tests.factories.fixtures import (
    CLIENTE_PASSWORD,
    DEFAULT_CAMPOS_EXTRAIDOS,
    DEFAULT_OTP,
    TALLER_NOMBRE,
)
from tests.factories.models import (
    create_documento,
    create_poliza,
    create_resultado_extraccion,
)
from tests.factories.payloads import (
    asistencia_payload,
    cliente_payload,
    login_payload,
    poliza_payload,
    revision_documento_payload,
    taller_payload,
    vehiculo_payload,
    vinculacion_payload,
)
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_complete_universe_end_to_end(
    db_session: AsyncSession,
    base_scenario: ScenarioBundle,
):
    """Executes the entire 0-to-100% operational lifecycle with live components and zero mocks."""
    mailpit_host = os.getenv("MAILPIT_HOST", "localhost")
    mailpit_http_port = os.getenv("MAILPIT_HTTP_PORT", "8025")
    mailpit_api = f"http://{mailpit_host}:{mailpit_http_port}/api/v1"

    # =========================================================================
    # FASE 1: Administrador configura catálogos globales
    # =========================================================================
    async with make_client() as anon_client:
        admin_login = await anon_client.post(
            "/api/v1/auth/login",
            json=login_payload(base_scenario.admin_user.email),
        )
        assert admin_login.status_code == 200, f"Login de Administrador debe ser exitoso: {admin_login.text}"
        admin_token = admin_login.json()["access_token"]

    async with make_client(admin_token) as admin_client:
        # Crear Taller Mecánico Afiliado
        taller_res = await admin_client.post(
            "/api/v1/talleres",
            json=taller_payload(),
        )
        assert taller_res.status_code in [200, 201], f"Admin debe poder crear taller afiliado: {taller_res.text}"
        assert taller_res.json()["nombre"] == TALLER_NOMBRE

        # Crear Servicio de Asistencia
        asistencia_res = await admin_client.post(
            "/api/v1/asistencias",
            json=asistencia_payload(),
        )
        assert asistencia_res.status_code in [200, 201], f"Admin debe poder crear asistencia: {asistencia_res.text}"

    # =========================================================================
    # FASE 2: Agente registra Cliente con Cédula Oficial y Correo
    # =========================================================================
    async with make_client() as anon_client:
        agente_login = await anon_client.post(
            "/api/v1/auth/login",
            json=login_payload(base_scenario.broker_user.email),
        )
        assert agente_login.status_code == 200, f"Login de Agente debe ser exitoso: {agente_login.text}"
        agente_token = agente_login.json()["access_token"]

    # Generar cliente mediante payload canónico (Módulo 10 garantizado)
    c_payload = cliente_payload()
    cedula_cliente = c_payload["identificacion"]
    email_cliente = c_payload["email"]

    async with make_client(agente_token) as agente_client:
        cliente_res = await agente_client.post(
            "/api/v1/clientes",
            json=c_payload,
        )
        assert cliente_res.status_code in [200, 201], f"Agente debe poder registrar cliente: {cliente_res.text}"
        cliente_data = cliente_res.json()
        cliente_id = cliente_data["id"]
        otp_generado = cliente_data["codigo_vinculacion"]
        assert len(otp_generado) == 6, "El código OTP generado debe tener 6 dígitos."

    # =========================================================================
    # FASE 3: Verificación de Envío SMTP e Interceptación en Mailpit
    # =========================================================================
    target_msg = None
    async with httpx.AsyncClient() as mail_client:
        for _ in range(15):
            mail_resp = await mail_client.get(f"{mailpit_api}/messages")
            assert mail_resp.status_code == 200, "Mailpit API debe estar accesible."
            messages = mail_resp.json().get("messages", [])
            target_msg = next(
                (m for m in messages if any(email_cliente in t.get("Address", "") for t in m.get("To", []))),
                None,
            )
            if target_msg:
                break
            await asyncio.sleep(0.3)

        assert target_msg is not None, f"Mailpit debe haber capturado el correo para {email_cliente}."
        msg_detail = (await mail_client.get(f"{mailpit_api}/message/{target_msg['ID']}")).json()
        assert otp_generado in msg_detail.get("Text", ""), "El cuerpo del correo capturado debe contener el OTP exacto."

    # =========================================================================
    # FASE 4: Cliente Asegurado activa su cuenta móvil con el OTP
    # =========================================================================
    nueva_password_cliente = CLIENTE_PASSWORD
    vinc_data = vinculacion_payload(
        cedula=cedula_cliente,
        codigo_otp=otp_generado,
        password=nueva_password_cliente,
        email=email_cliente,
    )
    async with make_client() as anon_client:
        activacion_res = await anon_client.post(
            "/api/v1/auth/vinculacion",
            json=vinc_data,
        )
        assert activacion_res.status_code in [200, 201], f"La activación con OTP válido debe ser exitosa: {activacion_res.text}"

        # Login móvil polimórfico del Cliente usando su CÉDULA
        cliente_login = await anon_client.post(
            "/api/v1/auth/login",
            json=login_payload(cedula_cliente, password=nueva_password_cliente),
        )
        assert cliente_login.status_code == 200, f"El cliente debe autenticarse usando su cédula: {cliente_login.text}"
        cliente_token = cliente_login.json()["access_token"]

    # =========================================================================
    # FASE 5: Vehículo, Documento OCR y Corrección de Campos (HU-06)
    # =========================================================================
    v_payload = vehiculo_payload(cliente_id)
    placa_cliente = v_payload["placa"]
    async with make_client(agente_token) as agente_client:
        vehiculo_res = await agente_client.post(
            "/api/v1/vehiculos",
            json=v_payload,
        )
        assert vehiculo_res.status_code in [200, 201], f"Creación de vehículo debe ser exitosa: {vehiculo_res.text}"
        vehiculo_id = vehiculo_res.json()["id"]

        # Crear documento y resultado de extracción OCR usando Model Factories
        doc = await create_documento(
            db_session,
            nombre_archivo=f"matricula_{placa_cliente.lower().replace('-', '_')}.pdf",
        )
        ocr_campos_con_error = {**DEFAULT_CAMPOS_EXTRAIDOS, "placa": f"{placa_cliente[:-1]}0"}
        await create_resultado_extraccion(
            db_session,
            documento_id=doc.id,
            campos_extraidos=ocr_campos_con_error,
        )

        # HU-06: Agente revisa y corrige el campo de placa
        rev_payload = revision_documento_payload(
            campos_extraidos={**DEFAULT_CAMPOS_EXTRAIDOS, "placa": placa_cliente},
            estado_extraccion="completado",
        )
        revision_res = await agente_client.patch(
            f"/api/v1/documentos/{doc.id}/revision",
            json=rev_payload,
        )
        assert revision_res.status_code == 200, "Agente debe poder revisar y confirmar campos OCR."
        assert revision_res.json()["campos_extraidos"]["placa"] == placa_cliente

        # =========================================================================
        # FASE 6: Emisión de Póliza con Deducibles (SC-2026-001) y Pagos (HU-20)
        # =========================================================================
        p_payload = poliza_payload(
            cliente_id=cliente_id,
            vehiculo_id=vehiculo_id,
        )
        poliza_res = await agente_client.post(
            "/api/v1/polizas",
            json=p_payload,
        )
        assert poliza_res.status_code in [200, 201], f"La póliza debe emitirse correctamente: {poliza_res.text}"
        poliza_data = poliza_res.json()
        poliza_id = poliza_data["id"]
        assert poliza_data["estado"] == "activa"

    # Verificar que el cronograma de pagos (HU-20) se generó en la base de datos
    async with make_client(cliente_token) as cliente_client:
        pagos_res = await cliente_client.get(f"/api/v1/polizas/{poliza_id}/pagos")
        assert pagos_res.status_code == 200, "El cliente debe poder consultar sus pagos (HU-20)."
        cuotas = pagos_res.json()
        assert len(cuotas) >= MIN_CUOTAS_POLIZA, "Debe existir al menos una cuota en el cronograma."
        assert float(cuotas[0]["monto_usd"]) == p_payload["prima_mensual"]

    # =========================================================================
    # FASE 7: Scheduler diario ejecuta transiciones temporales
    # =========================================================================
    hoy = date.today()
    poliza_futura = await create_poliza(
        db_session,
        cliente_id=uuid.UUID(cliente_id),
        vehiculo_id=uuid.UUID(vehiculo_id),
        fecha_inicio=hoy + timedelta(days=1),
        fecha_fin=hoy + timedelta(days=366),
        estado=EstadoPoliza.PENDIENTE,
    )

    # Ejecutar transición simulando el avance a la fecha de inicio
    res_sched = await ejecutar_transiciones_polizas(db_session, fecha_referencia=hoy + timedelta(days=1))
    assert res_sched["activadas"] >= 1, "El scheduler debe activar pólizas pendientes cuya fecha llegó."
    await db_session.refresh(poliza_futura)
    assert poliza_futura.estado == EstadoPoliza.ACTIVA

    # =========================================================================
    # FASE 8: Pruebas de Seguridad Hostil en Profundidad
    # =========================================================================
    # 8.1 Anti-BOLA: Cliente ajeno (Cliente B del escenario) no puede acceder a esta póliza ni a sus pagos
    async with make_client(base_scenario.token_b) as otro_client:
        bola_poliza = await otro_client.get(f"/api/v1/polizas/{poliza_id}")
        assert bola_poliza.status_code == 404, "Anti-BOLA: cliente ajeno debe recibir 404 en póliza."

        bola_pagos = await otro_client.get(f"/api/v1/polizas/{poliza_id}/pagos")
        assert bola_pagos.status_code == 404, "Anti-BOLA: cliente ajeno debe recibir 404 en pagos."

    # 8.2 Anti-IDOR en Descargas: Intento de descarga de documento no asociado
    async with make_client(cliente_token) as cliente_client:
        idor_res = await cliente_client.get(f"/api/v1/documentos/{doc.id}/descargar")
        assert idor_res.status_code in [403, 404], "Anti-IDOR debe denegar la descarga no autorizada."

    # 8.3 Rechazo de caracteres nulos (Null-Byte Injection)
    async with make_client() as anon_client:
        null_byte_res = await anon_client.post(
            "/api/v1/auth/login",
            json=login_payload(f"{base_scenario.admin_user.email}\x00malicious"),
        )
        assert null_byte_res.status_code == 422, "Pydantic debe rechazar inyección de byte nulo con 422."

    # 8.4 Bloqueo / Invalidación de OTP tras intentos fallidos consecutivos
    brute_payload = cliente_payload()
    cedula_brute = brute_payload["identificacion"]
    async with make_client(agente_token) as agente_client:
        res_brute_cli = await agente_client.post("/api/v1/clientes", json=brute_payload)
        assert res_brute_cli.status_code == 201
        cliente_brute_id = uuid.UUID(res_brute_cli.json()["id"])

    # Reset rate limiter to isolate 3-failed-attempts OTP lockout from IP-level throttling
    rate_limiter.reset()
    async with make_client() as anon_client:
        for _ in range(MAX_FAILED_OTP_ATTEMPTS):
            res_fail = await anon_client.post(
                "/api/v1/auth/vinculacion",
                json=vinculacion_payload(
                    cedula=cedula_brute,
                    codigo_otp=DEFAULT_OTP,
                    password=CLIENTE_PASSWORD,
                ),
            )
            assert res_fail.status_code == 400

    # Verificar que el código quedó consumido / invalidado en DB
    stmt_check_otp = select(CodigoVinculacion).where(CodigoVinculacion.cliente_id == cliente_brute_id)
    otp_db = (await db_session.execute(stmt_check_otp)).scalar_one()
    assert otp_db.consumido is True, "El OTP debe quedar invalidado (consumido=True) tras 3 fallos."
