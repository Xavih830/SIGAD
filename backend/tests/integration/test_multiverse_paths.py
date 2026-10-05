"""Multiverse Integration Test Suite — Happy, Bad, Horrible, and Shitty Paths.

This suite demonstrates:
1. Complete elimination of test data scattering via the Factory Pattern.
2. Full transactional savepoint rollback (zero persistent database pollution).
3. Comprehensive coverage across all 4 execution paths:
   - Happy Path: Legitimate, compliant domain workflows.
   - Bad Path: Expected business exceptions and client errors (400, 401, 404).
   - Horrible Path: Boundary violations, domain invariant corruption, malformed formats (422).
   - Shitty Path: Adversarial security attacks, BOLA/IDOR, privilege escalation, JWT forgery (401, 403, 404).
"""

import base64
import json
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import uuid

import jwt
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.rate_limit import rate_limiter
from app.domain.poliza_evaluator import EstadoPoliza
from tests.factories.helpers import (
    generar_cedula_valida,
    generar_fechas_poliza,
    generar_placa_valida,
)
from tests.factories.payloads import (
    cliente_payload,
    login_payload,
    poliza_payload,
    vehiculo_payload,
)
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


# ═════════════════════════════════════════════════════════════════════════════
# 1. HAPPY PATH: Legitimate, Compliant Domain Workflows
# ═════════════════════════════════════════════════════════════════════════════

async def test_happy_path_emision_poliza_flujo_completo(base_scenario: ScenarioBundle):
    """Happy Path: An authorized admin successfully issues a policy with auto-seeded deductible."""
    admin_token = base_scenario.admin_token
    c_id = base_scenario.cliente_a.id
    v_id = base_scenario.vehiculo_a.id

    payload = poliza_payload(
        c_id,
        v_id,
        valor_asegurado=25000.00,
        prima_mensual=55.00,
        kilometraje_emision=12000,
    )

    async with make_client(admin_token) as client:
        response = await client.post("/api/v1/polizas", json=payload)
        assert response.status_code == 201, response.text
        data = response.json()
        assert data["numero_poliza"] == payload["numero_poliza"]
        assert data["estado"] == "activa"
        assert data["kilometraje_emision"] == 12000
        # Automatically attached default general deductible (SC-2026-001)
        assert len(data["deducibles"]) >= 1
        assert float(data["deducibles"][0]["porcentaje_valor"]) == 10.0


async def test_happy_path_registro_cliente_y_vehiculo_con_formatos_oficiales(base_scenario: ScenarioBundle):
    """Happy Path: Register a client with a valid Módulo 10 Cédula and vehicle with ANT plate."""
    admin_token = base_scenario.admin_token
    c_payload = cliente_payload()

    async with make_client(admin_token) as client:
        res_c = await client.post("/api/v1/clientes", json=c_payload)
        assert res_c.status_code == 201, res_c.text
        cliente_creado = res_c.json()

        v_payload = vehiculo_payload(cliente_creado["id"])
        res_v = await client.post("/api/v1/vehiculos", json=v_payload)
        assert res_v.status_code == 201, res_v.text
        vehiculo_creado = res_v.json()
        assert vehiculo_creado["placa"] == v_payload["placa"]


async def test_happy_path_login_polimorfico(base_scenario: ScenarioBundle):
    """Happy Path: Polymorphic login succeeds both via corporate email and via Ecuadorian national ID."""
    async with make_client() as client:
        # 1. Login by Email (Admin)
        res_email = await client.post(
            "/api/v1/auth/login",
            json=login_payload(base_scenario.admin_user.email),
        )
        assert res_email.status_code == 200, res_email.text
        assert "access_token" in res_email.json()

        # 2. Login by Cédula (Cliente A)
        res_cedula = await client.post(
            "/api/v1/auth/login",
            json=login_payload(base_scenario.cliente_a.identificacion),
        )
        assert res_cedula.status_code == 200, res_cedula.text
        assert "access_token" in res_cedula.json()


async def test_happy_path_transicion_estado_poliza(base_scenario: ScenarioBundle):
    """Happy Path: Admin successfully transitions policy state to 'cancelada'."""
    admin_token = base_scenario.admin_token
    poliza_id = base_scenario.poliza_a.id

    async with make_client(admin_token) as client:
        response = await client.patch(
            f"/api/v1/polizas/{poliza_id}/estado",
            json={"estado": "cancelada"},
        )
        assert response.status_code == 200, response.text
        assert response.json()["estado"] == "cancelada"


# ═════════════════════════════════════════════════════════════════════════════
# 2. BAD PATH: Business Exceptions & Expected Client Errors (400, 401, 404)
# ═════════════════════════════════════════════════════════════════════════════

async def test_bad_path_emision_cliente_inexistente(base_scenario: ScenarioBundle):
    """Bad Path: Attempting to issue a policy for a non-existent client returns clean 404."""
    admin_token = base_scenario.admin_token
    v_id = base_scenario.vehiculo_a.id
    payload = poliza_payload(uuid.uuid4(), v_id)

    async with make_client(admin_token) as client:
        response = await client.post("/api/v1/polizas", json=payload)
        assert response.status_code == 404
        assert "no existe" in response.json()["detail"].lower()


async def test_bad_path_emision_vehiculo_inexistente(base_scenario: ScenarioBundle):
    """Bad Path: Attempting to issue a policy for a non-existent vehicle returns clean 404."""
    admin_token = base_scenario.admin_token
    c_id = base_scenario.cliente_a.id
    payload = poliza_payload(c_id, uuid.uuid4())

    async with make_client(admin_token) as client:
        response = await client.post("/api/v1/polizas", json=payload)
        assert response.status_code == 404
        assert "no existe" in response.json()["detail"].lower()


async def test_bad_path_numero_poliza_duplicado(base_scenario: ScenarioBundle):
    """Bad Path: Attempting to register a duplicate policy number returns 400 Bad Request."""
    admin_token = base_scenario.admin_token
    c_id = base_scenario.cliente_a.id
    v_id = base_scenario.vehiculo_a.id
    # Use existing policy number from scenario
    payload = poliza_payload(c_id, v_id, numero_poliza=base_scenario.poliza_a.numero_poliza)

    async with make_client(admin_token) as client:
        response = await client.post("/api/v1/polizas", json=payload)
        assert response.status_code == 400
        assert "ya existe" in response.json()["detail"].lower()


async def test_bad_path_login_credenciales_invalidas(base_scenario: ScenarioBundle):
    """Bad Path: Incorrect password returns 401 with generic anti-enumeration error."""
    async with make_client() as client:
        response = await client.post(
            "/api/v1/auth/login",
            json=login_payload(base_scenario.admin_user.email, password="WrongPassword999!"),
        )
        assert response.status_code == 401
        assert "no son válidas" in response.json()["detail"]


async def test_bad_path_consulta_poliza_id_inexistente(base_scenario: ScenarioBundle):
    """Bad Path: Querying a non-existent policy UUID returns 404."""
    admin_token = base_scenario.admin_token
    async with make_client(admin_token) as client:
        response = await client.get(f"/api/v1/polizas/{uuid.uuid4()}")
        assert response.status_code == 404


# ═════════════════════════════════════════════════════════════════════════════
# 3. HORRIBLE PATH: Boundary Violations, Invariants & Malformed Input (422)
# ═════════════════════════════════════════════════════════════════════════════

async def test_horrible_path_poliza_cronologia_invertida_o_cero(base_scenario: ScenarioBundle):
    """Horrible Path: Inverted dates (end < start) or zero-duration policy rejected with 422."""
    admin_token = base_scenario.admin_token
    c_id = base_scenario.cliente_a.id
    v_id = base_scenario.vehiculo_a.id

    async with make_client(admin_token) as client:
        # Case A: Inverted dates
        p_inv = poliza_payload(
            c_id, v_id,
            fecha_inicio="2026-06-01",
            fecha_fin="2026-01-01",
        )
        res_inv = await client.post("/api/v1/polizas", json=p_inv)
        assert res_inv.status_code == 422

        # Case B: Zero duration (same day)
        p_zero = poliza_payload(
            c_id, v_id,
            fecha_inicio="2026-06-01",
            fecha_fin="2026-06-01",
        )
        res_zero = await client.post("/api/v1/polizas", json=p_zero)
        assert res_zero.status_code == 422


async def test_horrible_path_poliza_vigencia_mayor_a_5_anios(base_scenario: ScenarioBundle):
    """Horrible Path: Policy duration exceeding statutory 5 years (1826 days) rejected with 422."""
    admin_token = base_scenario.admin_token
    c_id = base_scenario.cliente_a.id
    v_id = base_scenario.vehiculo_a.id

    p_5yr = poliza_payload(
        c_id, v_id,
        fecha_inicio="2026-01-01",
        fecha_fin="2031-01-05",  # Exceeds 5 years
    )
    async with make_client(admin_token) as client:
        response = await client.post("/api/v1/polizas", json=p_5yr)
        assert response.status_code == 422
        assert "5 años" in response.text


async def test_horrible_path_cliente_cedula_violaciones_modulo_10(base_scenario: ScenarioBundle):
    """Horrible Path: Rejection of corrupt Ecuadorian IDs (invalid province, third digit, check digit)."""
    admin_token = base_scenario.admin_token

    casos_corruptos = [
        "2501234567",  # Provincia 25 no existe en Ecuador
        "9901234567",  # Provincia 99 no existe
        "0981234567",  # Tercer dígito 8 prohibido para personas naturales
        "0926687850",  # Check digit adulterado (el válido es 6)
        "12345",       # Longitud insuficiente
        "0926687856ABCD",  # Caracteres no numéricos
    ]

    async with make_client(admin_token) as client:
        for cedula_invalida in casos_corruptos:
            payload = cliente_payload(identificacion=cedula_invalida)
            response = await client.post("/api/v1/clientes", json=payload)
            assert response.status_code == 422, f"Cédula corrupta '{cedula_invalida}' no fue rechazada!"


async def test_horrible_path_vehiculo_placas_ant_deformes(base_scenario: ScenarioBundle):
    """Horrible Path: Rejection of deformed, non-ANT vehicle license plates."""
    admin_token = base_scenario.admin_token
    c_id = base_scenario.cliente_a.id

    placas_deformes = [
        "INVALID",
        "123-ABCD",
        "PBA-12",
        "PBA-12345",
        "pba-1234",
        "!!!-9999",
    ]

    async with make_client(admin_token) as client:
        for placa in placas_deformes:
            payload = vehiculo_payload(c_id, placa=placa)
            response = await client.post("/api/v1/vehiculos", json=payload)
            assert response.status_code == 422, f"Placa deforme '{placa}' no fue rechazada!"


async def test_horrible_path_montos_financieros_negativos_o_cero(base_scenario: ScenarioBundle):
    """Horrible Path: Zero or negative insured amounts and premiums rejected with 422."""
    admin_token = base_scenario.admin_token
    c_id = base_scenario.cliente_a.id
    v_id = base_scenario.vehiculo_a.id

    async with make_client(admin_token) as client:
        # Case A: Insured value <= 0
        p_val_zero = poliza_payload(c_id, v_id, valor_asegurado=0)
        assert (await client.post("/api/v1/polizas", json=p_val_zero)).status_code == 422

        p_val_neg = poliza_payload(c_id, v_id, valor_asegurado=-15000)
        assert (await client.post("/api/v1/polizas", json=p_val_neg)).status_code == 422

        # Case B: Premium <= 0
        p_pri_zero = poliza_payload(c_id, v_id, prima_mensual=0)
        assert (await client.post("/api/v1/polizas", json=p_pri_zero)).status_code == 422

        # Case C: Mileage < 0
        p_km_neg = poliza_payload(c_id, v_id, kilometraje_emision=-500)
        assert (await client.post("/api/v1/polizas", json=p_km_neg)).status_code == 422


async def test_horrible_path_inyeccion_sql_en_login_y_consultas(db_session: AsyncSession):
    """Horrible Path: SQL injection payloads in auth must be handled safely via parameterized ORM."""
    async with make_client() as client:
        sql_injections = [
            "' OR '1'='1' --",
            "admin'--",
            "'; DROP TABLE polizas; --",
            "' UNION SELECT * FROM usuarios --",
        ]
        for sqli in sql_injections:
            rate_limiter.reset()
            response = await client.post(
                "/api/v1/auth/login",
                json=login_payload(identificador=sqli, password="Password123!"),
            )
            # Must reject with 401 or 422, NEVER crash with 500
            assert response.status_code in (401, 422), f"SQLi payload provoco código inesperado {response.status_code}"


# ═════════════════════════════════════════════════════════════════════════════
# 4. SHITTY PATH: Adversarial Attacks, BOLA/IDOR, Role Escalation & JWT Forgery
# ═════════════════════════════════════════════════════════════════════════════

async def test_shitty_path_bola_idor_acceso_cruzado_entre_inquilinos(base_scenario: ScenarioBundle):
    """Shitty Path: Malicious Client A attempts to access or mutate Client B's policy or vehicle."""
    token_a = base_scenario.token_a
    poliza_b = base_scenario.poliza_b
    vehiculo_b = base_scenario.vehiculo_b

    async with make_client(token_a) as client:
        # Attack 1: Client A tries to read Client B's policy -> 404 (Anti-BOLA query level)
        res_p = await client.get(f"/api/v1/polizas/{poliza_b.id}")
        assert res_p.status_code == 404, "BOLA breach: Client A accessed Client B's policy!"

        # Attack 2: Client A tries to read Client B's deductibles -> 404
        res_d = await client.get(f"/api/v1/polizas/{poliza_b.id}/deducibles")
        assert res_d.status_code == 404, "BOLA breach: Client A accessed Client B's deductibles!"

        # Attack 3: Client A tries to read Client B's vehicle -> 404
        res_v = await client.get(f"/api/v1/vehiculos/{vehiculo_b.id}")
        assert res_v.status_code == 404, "BOLA breach: Client A accessed Client B's vehicle!"


async def test_shitty_path_escalamiento_de_privilegios_rol_cliente(base_scenario: ScenarioBundle):
    """Shitty Path: Client attempts admin actions (issuing policies, changing status) -> 403 Forbidden."""
    token_cliente = base_scenario.token_a
    c_id = base_scenario.cliente_a.id
    v_id = base_scenario.vehiculo_a.id
    poliza_id = base_scenario.poliza_a.id

    async with make_client(token_cliente) as client:
        # Attack 1: Client tries to issue a policy
        p_payload = poliza_payload(c_id, v_id)
        res_emit = await client.post("/api/v1/polizas", json=p_payload)
        assert res_emit.status_code == 403, "Privilege escalation: Client was able to issue a policy!"

        # Attack 2: Client tries to cancel/alter a policy state
        res_state = await client.patch(
            f"/api/v1/polizas/{poliza_id}/estado",
            json={"estado": "cancelada"},
        )
        assert res_state.status_code == 403, "Privilege escalation: Client was able to alter policy state!"


async def test_shitty_path_falsificacion_de_tokens_jwt(base_scenario: ScenarioBundle):
    """Shitty Path: JWT forgery attacks (None algorithm, tampered signature, expired tokens)."""
    admin_id = str(base_scenario.admin_user.id)

    async with make_client() as client:
        # Attack 1: "none" algorithm attack (manually constructed base64url header and payload)
        raw_header = base64.urlsafe_b64encode(b'{"alg":"none","typ":"JWT"}').decode().rstrip("=")
        raw_payload = base64.urlsafe_b64encode(json.dumps({"sub": admin_id}).encode()).decode().rstrip("=")
        none_token = f"{raw_header}.{raw_payload}."
        async with make_client(none_token) as forged_client:
            res_none = await forged_client.get("/api/v1/polizas")
            assert res_none.status_code == 401, "JWT breach: 'none' algorithm token was accepted!"

        # Attack 2: Tampered signature (valid token payload with forged signature)
        parts = base_scenario.admin_token.split(".")
        tampered_token = f"{parts[0]}.{parts[1]}.FORGED_SIGNATURE_HERE"
        async with make_client(tampered_token) as forged_client:
            res_tamp = await forged_client.get("/api/v1/polizas")
            assert res_tamp.status_code == 401, "JWT breach: Tampered signature was accepted!"

        # Attack 3: Expired token
        past_exp = datetime.now(timezone.utc) - timedelta(hours=2)
        jwt_key = settings.JWT_SECRET_KEY.get_secret_value() if hasattr(settings.JWT_SECRET_KEY, "get_secret_value") else str(settings.JWT_SECRET_KEY)
        expired_token = jwt.encode(
            {"sub": admin_id, "exp": past_exp},
            key=jwt_key,
            algorithm=settings.JWT_ALGORITHM,
        )
        async with make_client(expired_token) as expired_client:
            res_exp = await expired_client.get("/api/v1/polizas")
            assert res_exp.status_code == 401, "JWT breach: Expired token was accepted!"

        # Attack 4: Malformed Bearer header schemas
        for bad_header in ["Bearer ", "Token some_token", "Bearer not.a.jwt", "InvalidHeader"]:
            transport_client = make_client()
            transport_client.headers["Authorization"] = bad_header
            res_bad = await transport_client.get("/api/v1/polizas")
            assert res_bad.status_code in (401, 403), f"Bad header '{bad_header}' was not rejected!"


async def test_shitty_path_inyeccion_caracteres_nulos_y_xss(base_scenario: ScenarioBundle):
    """Shitty Path: Adversarial injections containing null bytes and XSS payloads."""
    admin_token = base_scenario.admin_token

    async with make_client(admin_token) as client:
        # Case A: XSS in Client name (stored securely as text, never crashes or executes)
        xss_payload = cliente_payload(nombres='<script>alert("PWNED")</script>')
        res_xss = await client.post("/api/v1/clientes", json=xss_payload)
        assert res_xss.status_code == 201
        assert res_xss.json()["nombres"] == '<script>alert("PWNED")</script>'

        # Case B: Null Byte Injection in Login
        rate_limiter.reset()
        res_null = await client.post(
            "/api/v1/auth/login",
            json=login_payload(identificador="admin@sigad.ec\x00malicious", password="Password123!"),
        )
        assert res_null.status_code in (401, 422), "Null byte injection caused 500 error!"
