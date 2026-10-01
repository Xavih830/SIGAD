"""Consolidated integration tests for Polizas and Vehiculos REST API.

Verification Gate 3: alembic upgrade head && pytest tests/integration/test_polizas_api.py
"""

from datetime import date, timedelta
from decimal import Decimal
import uuid

import pytest

from tests.factories.payloads import poliza_payload, vehiculo_payload
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_crear_poliza_flujo_completo(seed_data: dict):
    """Test full policy creation flow including automatic default deductible."""
    admin_token = seed_data["tokens"]["admin"]
    cliente_a = seed_data["cliente_a"]
    vehiculo_a = seed_data["vehiculo_a"]

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


async def test_crear_poliza_fecha_fin_menor_rechaza_422(seed_data: dict):
    """FechaInvalidaException causes HTTP 422."""
    admin_token = seed_data["tokens"]["admin"]
    cliente_a = seed_data["cliente_a"]
    vehiculo_a = seed_data["vehiculo_a"]

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


async def test_crear_poliza_vigencia_mayor_a_5_anios_rechaza_422(seed_data: dict):
    """VigenciaExcedidaException causes HTTP 422."""
    admin_token = seed_data["tokens"]["admin"]
    cliente_a = seed_data["cliente_a"]
    vehiculo_a = seed_data["vehiculo_a"]

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


async def test_crear_vehiculo_con_placa_ant_valida(seed_data: dict):
    """Register vehicle with valid ANT license plate."""
    admin_token = seed_data["tokens"]["admin"]
    cliente_a = seed_data["cliente_a"]

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


async def test_crear_vehiculo_placa_invalida_rechaza_422(seed_data: dict):
    """Invalid plate rejected with 422 validation error."""
    admin_token = seed_data["tokens"]["admin"]
    cliente_a = seed_data["cliente_a"]

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

