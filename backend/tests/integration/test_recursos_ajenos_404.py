"""Pruebas de seguridad para respuesta 404 uniforme ante recursos inexistentes o ajenos.

Garantía de seguridad (Anti-Enumeration / Zero Information Leakage):
Tanto un identificador inexistente como un identificador perteneciente a otro cliente
deben retornar exactamente el mismo código HTTP (404) y el mismo cuerpo JSON
({"detail": "Recurso no encontrado."}), impidiendo que un atacante determine si un ID existe.
"""

import uuid

import pytest

from tests.factories.payloads import vehiculo_payload
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")

MENSAJE_UNIFORME = "Recurso no encontrado."


async def test_cliente_acceso_uniforme_404_cliente_detalle(base_scenario: ScenarioBundle):
    """GET /api/v1/clientes/{id}: recurso ajeno e inexistente retornan el mismo 404 y cuerpo."""
    token_a = base_scenario.token_a
    cliente_b = base_scenario.cliente_b
    fake_id = uuid.uuid4()

    async with make_client(token_a) as client:
        res_ajeno = await client.get(f"/api/v1/clientes/{cliente_b.id}")
        res_inexistente = await client.get(f"/api/v1/clientes/{fake_id}")

        assert res_ajeno.status_code == 404
        assert res_inexistente.status_code == 404
        assert res_ajeno.json() == res_inexistente.json()
        assert res_ajeno.json()["detail"] == MENSAJE_UNIFORME


async def test_cliente_acceso_uniforme_404_vehiculo_detalle(base_scenario: ScenarioBundle):
    """GET /api/v1/vehiculos/{id}: vehículo ajeno e inexistente retornan el mismo 404 y cuerpo."""
    token_a = base_scenario.token_a
    vehiculo_b = base_scenario.vehiculo_b
    fake_id = uuid.uuid4()

    async with make_client(token_a) as client:
        res_ajeno = await client.get(f"/api/v1/vehiculos/{vehiculo_b.id}")
        res_inexistente = await client.get(f"/api/v1/vehiculos/{fake_id}")

        assert res_ajeno.status_code == 404
        assert res_inexistente.status_code == 404
        assert res_ajeno.json() == res_inexistente.json()
        assert res_ajeno.json()["detail"] == MENSAJE_UNIFORME


async def test_cliente_crear_vehiculo_uniforme_404_cliente_id(base_scenario: ScenarioBundle):
    """POST /api/v1/vehiculos: cliente_id ajeno e inexistente retornan el mismo 404 y cuerpo."""
    token_a = base_scenario.token_a
    cliente_b = base_scenario.cliente_b
    fake_id = uuid.uuid4()

    async with make_client(token_a) as client:
        payload_ajeno = vehiculo_payload(cliente_b.id)
        payload_inexistente = vehiculo_payload(fake_id)

        res_ajeno = await client.post("/api/v1/vehiculos", json=payload_ajeno)
        res_inexistente = await client.post("/api/v1/vehiculos", json=payload_inexistente)

        assert res_ajeno.status_code == 404
        assert res_inexistente.status_code == 404
        assert res_ajeno.json() == res_inexistente.json()
        assert res_ajeno.json()["detail"] == MENSAJE_UNIFORME


async def test_cliente_acceso_uniforme_404_poliza_detalle(base_scenario: ScenarioBundle):
    """GET /api/v1/polizas/{id}: póliza ajena e inexistente retornan el mismo 404 y cuerpo."""
    token_a = base_scenario.token_a
    poliza_b = base_scenario.poliza_b
    fake_id = uuid.uuid4()

    async with make_client(token_a) as client:
        res_ajeno = await client.get(f"/api/v1/polizas/{poliza_b.id}")
        res_inexistente = await client.get(f"/api/v1/polizas/{fake_id}")

        assert res_ajeno.status_code == 404
        assert res_inexistente.status_code == 404
        assert res_ajeno.json() == res_inexistente.json()
        assert res_ajeno.json()["detail"] == MENSAJE_UNIFORME


async def test_cliente_acceso_uniforme_404_poliza_deducibles(base_scenario: ScenarioBundle):
    """GET /api/v1/polizas/{id}/deducibles: póliza ajena e inexistente retornan el mismo 404 y cuerpo."""
    token_a = base_scenario.token_a
    poliza_b = base_scenario.poliza_b
    fake_id = uuid.uuid4()

    async with make_client(token_a) as client:
        res_ajeno = await client.get(f"/api/v1/polizas/{poliza_b.id}/deducibles")
        res_inexistente = await client.get(f"/api/v1/polizas/{fake_id}/deducibles")

        assert res_ajeno.status_code == 404
        assert res_inexistente.status_code == 404
        assert res_ajeno.json() == res_inexistente.json()
        assert res_ajeno.json()["detail"] == MENSAJE_UNIFORME


async def test_cliente_acceso_uniforme_404_poliza_pagos(base_scenario: ScenarioBundle):
    """GET /api/v1/polizas/{id}/pagos: póliza ajena e inexistente retornan el mismo 404 y cuerpo."""
    token_a = base_scenario.token_a
    poliza_b = base_scenario.poliza_b
    fake_id = uuid.uuid4()

    async with make_client(token_a) as client:
        res_ajeno = await client.get(f"/api/v1/polizas/{poliza_b.id}/pagos")
        res_inexistente = await client.get(f"/api/v1/polizas/{fake_id}/pagos")

        assert res_ajeno.status_code == 404
        assert res_inexistente.status_code == 404
        assert res_ajeno.json() == res_inexistente.json()
        assert res_ajeno.json()["detail"] == MENSAJE_UNIFORME
