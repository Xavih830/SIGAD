"""Pruebas de integración para defensa BOLA a nivel de consulta SQL."""

import pytest

from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_cliente_solo_ve_sus_propias_polizas(base_scenario: ScenarioBundle):
    """Anti-BOLA query level: Cliente A list view must not contain Cliente B's policies."""
    token_a = base_scenario.token_a
    poliza_a = base_scenario.poliza_a
    poliza_b = base_scenario.poliza_b

    async with make_client(token_a) as client:
        response = await client.get("/api/v1/polizas")
        assert response.status_code == 200, response.text
        data = response.json()

        returned_ids = [p["id"] for p in data]
        assert str(poliza_a.id) in returned_ids, "La póliza de Cliente A debe figurar en su lista."
        assert str(poliza_b.id) not in returned_ids, (
            "Violación BOLA: La póliza de Cliente B se filtró en la consulta de Cliente A!"
        )


async def test_cliente_no_puede_acceder_a_poliza_ajena_por_id(base_scenario: ScenarioBundle):
    """Anti-BOLA: Direct access to another client's policy must return 404."""
    token_a = base_scenario.token_a
    poliza_b = base_scenario.poliza_b

    async with make_client(token_a) as client:
        response = await client.get(f"/api/v1/polizas/{poliza_b.id}")
        assert response.status_code == 404, (
            f"Esperado 404 para ocultar existencia de objeto ajeno, se obtuvo {response.status_code}"
        )


async def test_cliente_no_puede_acceder_a_deducibles_ajenos(base_scenario: ScenarioBundle):
    """Anti-BOLA: Querying deductibles of another client's policy must return 404."""
    token_a = base_scenario.token_a
    poliza_b = base_scenario.poliza_b

    async with make_client(token_a) as client:
        response = await client.get(f"/api/v1/polizas/{poliza_b.id}/deducibles")
        assert response.status_code == 404


async def test_cliente_no_puede_acceder_a_vehiculo_ajeno(base_scenario: ScenarioBundle):
    """Anti-BOLA: Querying another client's vehicle must return 404."""
    token_a = base_scenario.token_a
    vehiculo_b = base_scenario.vehiculo_b

    async with make_client(token_a) as client:
        response = await client.get(f"/api/v1/vehiculos/{vehiculo_b.id}")
        assert response.status_code == 404


async def test_admin_puede_ver_todas_las_polizas(base_scenario: ScenarioBundle):
    """Corporate users (admin) have global visibility across all tenants."""
    admin_token = base_scenario.admin_token
    poliza_a = base_scenario.poliza_a
    poliza_b = base_scenario.poliza_b

    async with make_client(admin_token) as client:
        response = await client.get("/api/v1/polizas")
        assert response.status_code == 200
        data = response.json()
        returned_ids = [p["id"] for p in data]
        assert str(poliza_a.id) in returned_ids
        assert str(poliza_b.id) in returned_ids
