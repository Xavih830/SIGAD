"""Integration tests for Failure Modes, Boundaries, and Security Invariants.

Design Philosophy:
- Testing for failure: the most valuable tests don't just assert happy paths,
  they verify that boundary violations, illegal states, duplicate records,
  tampered tokens, and unauthorized operations fail gracefully and predictably.
- Strict isolation: tests do NOT rely on or pollute persistent operational data.
"""

from datetime import date, timedelta
import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

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
# 1. PÓLIZAS: Boundary, Invariant & Negative Failure Tests
# ═════════════════════════════════════════════════════════════════════════════

async def test_rechazo_poliza_cliente_inexistente(base_scenario: ScenarioBundle):
    """Falla esperada: emision para cliente inexistente debe responder 404 sin violar foreign key con 500."""
    admin_token = base_scenario.admin_token
    vehiculo_a = base_scenario.vehiculo_a
    fake_cliente_id = uuid.uuid4()

    payload = poliza_payload(
        fake_cliente_id,
        vehiculo_a.id,
        numero_poliza=f"POL-FAIL-{uuid.uuid4().hex[:6]}",
        valor_asegurado=15000.00,
        prima_mensual=45.00,
        kilometraje_emision=20000,
    )
    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/polizas", json=payload)
        assert res.status_code == 404
        assert "no existe" in res.json()["detail"].lower()


async def test_rechazo_poliza_vehiculo_inexistente(base_scenario: ScenarioBundle):
    """Falla esperada: emision para vehiculo inexistente debe responder 404."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a
    fake_vehiculo_id = uuid.uuid4()

    payload = poliza_payload(
        cliente_a.id,
        fake_vehiculo_id,
        numero_poliza=f"POL-FAIL-{uuid.uuid4().hex[:6]}",
        valor_asegurado=15000.00,
        prima_mensual=45.00,
        kilometraje_emision=20000,
    )
    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/polizas", json=payload)
        assert res.status_code == 404
        assert "no existe" in res.json()["detail"].lower()


async def test_rechazo_poliza_numero_duplicado(base_scenario: ScenarioBundle):
    """Falla esperada: no se puede duplicar un numero_poliza ya existente."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a
    vehiculo_a = base_scenario.vehiculo_a
    poliza_a = base_scenario.poliza_a

    payload = poliza_payload(
        cliente_a.id,
        vehiculo_a.id,
        numero_poliza=poliza_a.numero_poliza,
        valor_asegurado=12000.00,
        prima_mensual=35.00,
        kilometraje_emision=15000,
    )
    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/polizas", json=payload)
        assert res.status_code == 400
        assert "ya existe una póliza" in res.json()["detail"].lower()


async def test_rechazo_poliza_escalamiento_rol_cliente(base_scenario: ScenarioBundle):
    """Falla esperada: un usuario con rol 'cliente' no tiene permisos para emitir polizas (403)."""
    token_cliente = base_scenario.token_a
    cliente_a = base_scenario.cliente_a
    vehiculo_a = base_scenario.vehiculo_a

    payload = poliza_payload(
        cliente_a.id,
        vehiculo_a.id,
        numero_poliza=f"POL-HACK-{uuid.uuid4().hex[:6]}",
        valor_asegurado=15000.00,
        prima_mensual=45.00,
        kilometraje_emision=20000,
    )
    async with make_client(token_cliente) as client:
        res = await client.post("/api/v1/polizas", json=payload)
        assert res.status_code == 403
        assert "acceso denegado" in res.json()["detail"].lower()


async def test_rechazo_poliza_fechas_identicas_duracion_cero(base_scenario: ScenarioBundle):
    """Falla esperada: vigencia con fecha_fin == fecha_inicio rechazada con 422."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a
    vehiculo_a = base_scenario.vehiculo_a
    hoy = date.today()

    payload = poliza_payload(
        cliente_a.id,
        vehiculo_a.id,
        numero_poliza=f"POL-ZERO-{uuid.uuid4().hex[:6]}",
        fecha_inicio=hoy,
        fecha_fin=hoy,
        valor_asegurado=15000.00,
        prima_mensual=45.00,
        kilometraje_emision=20000,
    )
    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/polizas", json=payload)
        assert res.status_code == 422
        assert "posterior a la fecha de inicio" in res.text


async def test_rechazo_actualizar_estado_poliza_inexistente(base_scenario: ScenarioBundle):
    """Falla esperada: PATCH sobre ID de poliza inexistente devuelve 404."""
    admin_token = base_scenario.admin_token
    fake_id = uuid.uuid4()

    async with make_client(admin_token) as client:
        res = await client.patch(
            f"/api/v1/polizas/{fake_id}/estado",
            json={"estado": "cancelada"},
        )
        assert res.status_code == 404
        assert "no encontrada" in res.json()["detail"].lower()


async def test_rechazo_actualizar_estado_poliza_valor_prohibido(base_scenario: ScenarioBundle):
    """Falla esperada: estados 'borrador' o 'error' estan estrictamente prohibidos (422)."""
    admin_token = base_scenario.admin_token
    poliza_a = base_scenario.poliza_a

    async with make_client(admin_token) as client:
        res = await client.patch(
            f"/api/v1/polizas/{poliza_a.id}/estado",
            json={"estado": "borrador"},
        )
        assert res.status_code == 422


# ═════════════════════════════════════════════════════════════════════════════
# 2. CLIENTES: Validation & Boundary Failure Tests
# ═════════════════════════════════════════════════════════════════════════════

async def test_rechazo_cliente_cedula_invalida_modulo_10(base_scenario: ScenarioBundle):
    """Falla esperada: cedula con digito verificador corrupto rechazada con 422."""
    admin_token = base_scenario.admin_token

    async with make_client(admin_token) as client:
        res = await client.post(
            "/api/v1/clientes",
            json=cliente_payload(
                identificacion="0926687859",  # Verificador correcto es 6, no 9
                nombres="Cliente Cedula Corrupta",
                email="corrupto@test.ec",
            ),
        )
        assert res.status_code == 422
        assert "inválida" in res.text.lower() or "módulo 10" in res.text.lower()


async def test_rechazo_cliente_cedula_provincia_invalida(base_scenario: ScenarioBundle):
    """Falla esperada: codigo de provincia 25 o 00 rechazado con 422."""
    admin_token = base_scenario.admin_token

    async with make_client(admin_token) as client:
        res = await client.post(
            "/api/v1/clientes",
            json=cliente_payload(
                identificacion="2500000000",  # Provincia 25 no existe en Ecuador
                nombres="Cliente Provincia Falsa",
            ),
        )
        assert res.status_code == 422
        assert "inválida" in res.text.lower() or "módulo 10" in res.text.lower()


async def test_rechazo_cliente_cedula_duplicada(base_scenario: ScenarioBundle):
    """Falla esperada: registrar dos veces la misma cedula debe retornar 400."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a

    async with make_client(admin_token) as client:
        res = await client.post(
            "/api/v1/clientes",
            json=cliente_payload(
                identificacion=cliente_a.identificacion,
                nombres="Nombre Duplicado",
            ),
        )
        assert res.status_code == 400
        assert "ya existe un cliente" in res.json()["detail"].lower()


async def test_rechazo_otp_cliente_inexistente(base_scenario: ScenarioBundle):
    """Falla esperada: regenerar OTP para cliente inexistente devuelve 404."""
    admin_token = base_scenario.admin_token
    fake_id = uuid.uuid4()

    async with make_client(admin_token) as client:
        res = await client.post(f"/api/v1/clientes/{fake_id}/otp")
        assert res.status_code == 404
        assert "no encontrado" in res.json()["detail"].lower()


# ═════════════════════════════════════════════════════════════════════════════
# 3. VEHÍCULOS: Boundary & Invariant Failure Tests
# ═════════════════════════════════════════════════════════════════════════════

async def test_rechazo_vehiculo_cliente_inexistente(base_scenario: ScenarioBundle):
    """Falla esperada: registrar vehiculo para cliente inexistente responde 404."""
    admin_token = base_scenario.admin_token
    fake_id = uuid.uuid4()

    async with make_client(admin_token) as client:
        res = await client.post(
            "/api/v1/vehiculos",
            json=vehiculo_payload(
                fake_id,
                placa=f"PBA-{uuid.uuid4().int % 9000 + 1000}",
                marca="Toyota",
                modelo="Yaris",
                anio=2022,
            ),
        )
        assert res.status_code == 404
        assert "no existe" in res.json()["detail"].lower()


async def test_rechazo_vehiculo_placa_duplicada(base_scenario: ScenarioBundle):
    """Falla esperada: registrar vehiculo con placa ya existente responde 400."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a
    vehiculo_a = base_scenario.vehiculo_a

    async with make_client(admin_token) as client:
        res = await client.post(
            "/api/v1/vehiculos",
            json=vehiculo_payload(
                cliente_a.id,
                placa=vehiculo_a.placa,  # Placa ya registrada
                marca="Chevrolet",
                modelo="Aveo",
                anio=2021,
            ),
        )
        assert res.status_code == 400
        assert "ya existe un vehículo" in res.json()["detail"].lower()


async def test_rechazo_vehiculo_placa_malformada(base_scenario: ScenarioBundle):
    """Falla esperada: formatos de placa antiguos o con caracteres ilegales rechazados con 422."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a

    placas_invalidas = [
        "123-ABCD",    # Numeros primero
        "P-1234",      # Solo 1 letra
        "PB-12",       # Solo 2 digitos (minimo 4)
        "PBA-123",     # Formato antiguo de 3 digitos no admitido en nuevas altas
        "PBA-12345",   # 5 digitos
        "pba-1234",    # Minusculas no normalizadas
    ]

    async with make_client(admin_token) as client:
        for p in placas_invalidas:
            res = await client.post(
                "/api/v1/vehiculos",
                json=vehiculo_payload(
                    cliente_a.id,
                    placa=p,
                    marca="Toyota",
                    modelo="Corolla",
                    anio=2022,
                ),
            )
            assert res.status_code == 422, f"Placa inválida '{p}' debió ser rechazada con 422"


# ═════════════════════════════════════════════════════════════════════════════
# 4. SEGURIDAD: Token Tampering & Injection Failure Tests
# ═════════════════════════════════════════════════════════════════════════════

async def test_rechazo_token_jwt_manipulado_o_adulterado():
    """Falla esperada: token con firma criptografica adulterada debe ser rechazado con 401."""
    token_falso = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0In0.fake_signature_hash_bytes"

    async with make_client(token_falso) as client:
        res = await client.get("/api/v1/polizas")
        assert res.status_code == 401


async def test_rechazo_token_jwt_texto_plano_malformado():
    """Falla esperada: header Authorization sin formato JWT debe retornar 401."""
    async with make_client("texto-plano-no-es-jwt") as client:
        res = await client.get("/api/v1/polizas")
        assert res.status_code == 401


async def test_rechazo_login_sql_injection_en_identificador(db_session: AsyncSession):
    """Falla esperada: inyeccion SQL en identificador de login es neutralizada y rechazada con 401."""
    payloads_sqli = [
        "' OR '1'='1",
        "admin' --",
        "'; DROP TABLE usuarios; --",
        "1' OR 1=1 #",
    ]

    async with make_client() as client:
        for sql_payload in payloads_sqli:
            res = await client.post(
                "/api/v1/auth/login",
                json=login_payload(identificador=sql_payload, password="Password123#"),
            )
            # Debe responder 401 de credenciales invalidas, NUNCA 500 por error de sintaxis SQL
            assert res.status_code in (401, 429), (
                f"SQLi payload '{sql_payload}' provocó estado inesperado {res.status_code}"
            )
            if res.status_code == 401:
                assert "no son válidas" in res.json()["detail"]


# ═════════════════════════════════════════════════════════════════════════════
# 5. CATÁLOGO: Non-existent Resource Failure Tests
# ═════════════════════════════════════════════════════════════════════════════

async def test_rechazo_taller_inexistente(db_session: AsyncSession):
    """Falla esperada: consultar taller con UUID inexistente responde 404."""
    fake_id = uuid.uuid4()
    async with make_client() as client:
        res = await client.get(f"/api/v1/talleres/{fake_id}")
        assert res.status_code == 404
        assert "no encontrado" in res.json()["detail"].lower()


async def test_rechazo_asistencia_inexistente(db_session: AsyncSession):
    """Falla esperada: consultar servicio de asistencia con UUID inexistente responde 404."""
    fake_id = uuid.uuid4()
    async with make_client() as client:
        res = await client.get(f"/api/v1/asistencias/{fake_id}")
        assert res.status_code == 404
        assert "no encontrado" in res.json()["detail"].lower()
