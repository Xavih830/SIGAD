"""Consolidated integration tests for Polizas and Vehiculos REST API.

Verification Gate 3: alembic upgrade head && pytest tests/integration/test_polizas_api.py
"""

from datetime import date, timedelta
from decimal import Decimal
import uuid

import pytest

from tests.factories.payloads import poliza_payload, vehiculo_payload
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_crear_poliza_flujo_completo(base_scenario: ScenarioBundle):
    """Test full policy creation flow including automatic default deductible."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a
    vehiculo_a = base_scenario.vehiculo_a

    poliza_num = f"POL-TEST-{uuid.uuid4().hex[:6].upper()}"
    payload = poliza_payload(
        cliente_id=cliente_a.id,
        vehiculo_id=vehiculo_a.id,
        numero_poliza=poliza_num,
    )
    async with make_client(admin_token) as client:
        response = await client.post(
            "/api/v1/polizas",
            json=payload,
        )
        assert response.status_code == 201, response.text
        data = response.json()
        assert data["numero_poliza"] == poliza_num
        assert data["estado"] == "activa"
        assert data["kilometraje_emision"] == 18200
        # Default deductible (SC-2026-001) automatically seeded
        assert len(data["deducibles"]) == 1
        assert data["deducibles"][0]["tipo_siniestro"] == "general"
        assert float(data["deducibles"][0]["porcentaje_valor"]) == 10.0
        assert float(data["deducibles"][0]["monto_minimo_usd"]) == 200.0


async def test_crear_poliza_fecha_fin_menor_rechaza_422(base_scenario: ScenarioBundle):
    """FechaInvalidaException causes HTTP 422."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a
    vehiculo_a = base_scenario.vehiculo_a

    payload = poliza_payload(
        cliente_id=cliente_a.id,
        vehiculo_id=vehiculo_a.id,
        numero_poliza=f"POL-FAIL-{uuid.uuid4().hex[:6]}",
        fecha_inicio=date(2026, 6, 1).isoformat(),
        fecha_fin=date(2026, 5, 1).isoformat(),
        valor_asegurado=15000.00,
        prima_mensual=40.00,
        kilometraje_emision=10000,
    )
    async with make_client(admin_token) as client:
        response = await client.post(
            "/api/v1/polizas",
            json=payload,
        )
        assert response.status_code == 422
        assert "posterior a la fecha de inicio" in response.text


async def test_crear_poliza_vigencia_mayor_a_5_anios_rechaza_422(base_scenario: ScenarioBundle):
    """VigenciaExcedidaException causes HTTP 422."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a
    vehiculo_a = base_scenario.vehiculo_a

    fecha_inicio = date(2026, 1, 1)
    fecha_fin = date(2031, 1, 2)  # 5 años + 1 día

    payload = poliza_payload(
        cliente_id=cliente_a.id,
        vehiculo_id=vehiculo_a.id,
        numero_poliza=f"POL-5YR-{uuid.uuid4().hex[:6]}",
        fecha_inicio=fecha_inicio.isoformat(),
        fecha_fin=fecha_fin.isoformat(),
        valor_asegurado=15000.00,
        prima_mensual=40.00,
        kilometraje_emision=10000,
    )
    async with make_client(admin_token) as client:
        response = await client.post(
            "/api/v1/polizas",
            json=payload,
        )
        assert response.status_code == 422
        assert "5 años" in response.text


async def test_crear_vehiculo_con_placa_ant_valida(base_scenario: ScenarioBundle):
    """Register vehicle with valid ANT license plate."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a

    placa_valida = f"PBA-{str(uuid.uuid4().int)[:4]}"
    payload = vehiculo_payload(
        cliente_id=cliente_a.id,
        placa=placa_valida,
        marca="Hyundai",
        modelo="Tucson",
        anio=2024,
    )
    async with make_client(admin_token) as client:
        response = await client.post(
            "/api/v1/vehiculos",
            json=payload,
        )
        assert response.status_code == 201, response.text
        assert response.json()["placa"] == placa_valida


async def test_crear_vehiculo_placa_invalida_rechaza_422(base_scenario: ScenarioBundle):
    """Invalid plate rejected with 422 validation error."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a

    payload = vehiculo_payload(
        cliente_id=cliente_a.id,
        placa="XYZ-123",  # Formato antiguo 3L+3D no permitido
        marca="Hyundai",
        modelo="Tucson",
        anio=2024,
    )
    async with make_client(admin_token) as client:
        response = await client.post(
            "/api/v1/vehiculos",
            json=payload,
        )
        assert response.status_code == 422


async def test_listar_polizas_paginacion_limites_y_validacion(base_scenario: ScenarioBundle):
    """Paginación en /api/v1/polizas respeta limit, skip y valida límites canónicos (422 si > 100 o < 0)."""
    admin_token = base_scenario.admin_token

    async with make_client(admin_token) as client:
        # Petición por defecto (limit=50, skip=0)
        res_default = await client.get("/api/v1/polizas")
        assert res_default.status_code == 200
        assert isinstance(res_default.json(), list)

        # Petición con limit=1
        res_limit1 = await client.get("/api/v1/polizas?limit=1")
        assert res_limit1.status_code == 200
        assert len(res_limit1.json()) <= 1

        # Validación fail-fast: limit > 100 debe rechazar con 422
        res_overflow = await client.get("/api/v1/polizas?limit=101")
        assert res_overflow.status_code == 422

        # Validación fail-fast: skip < 0 debe rechazar con 422
        res_negative_skip = await client.get("/api/v1/polizas?skip=-1")
        assert res_negative_skip.status_code == 422


async def test_listar_vehiculos_paginacion_limites_y_validacion(base_scenario: ScenarioBundle):
    """Paginación en /api/v1/vehiculos respeta limit, skip y valida límites canónicos (422 si > 100 o < 0)."""
    admin_token = base_scenario.admin_token

    async with make_client(admin_token) as client:
        # Petición por defecto
        res_default = await client.get("/api/v1/vehiculos")
        assert res_default.status_code == 200
        assert isinstance(res_default.json(), list)

        # Petición con limit=1
        res_limit1 = await client.get("/api/v1/vehiculos?limit=1")
        assert res_limit1.status_code == 200
        assert len(res_limit1.json()) <= 1

        # Validación fail-fast: limit > 100 debe rechazar con 422
        res_overflow = await client.get("/api/v1/vehiculos?limit=101")
        assert res_overflow.status_code == 422

        # Validación fail-fast: skip < 0 debe rechazar con 422
        res_negative_skip = await client.get("/api/v1/vehiculos?skip=-1")
        assert res_negative_skip.status_code == 422


