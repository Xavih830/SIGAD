"""Integration test for Anti-BOLA defense-in-depth at SQL query level (Sección 17.1).

Obligatory Test #13 / #23 (Section 21 of poryecto.md).
Verifies:
  1. A client can only query their own policies (GET /api/v1/polizas).
  2. Direct object reference attempts by Client A accessing Client B's policy
     (GET /api/v1/polizas/{id_b}) return HTTP 404, preventing ID enumeration.
  3. Direct access to Client B's deductibles (GET /api/v1/polizas/{id_b}/deducibles) returns 404.
  4. Direct access to Client B's vehicle (GET /api/v1/vehiculos/{id_b}) returns 404.
  5. Administrators can view and query all policies across all clients.
"""

import pytest

from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_cliente_solo_ve_sus_propias_polizas(seed_data: dict):
    """Anti-BOLA query level: Cliente A list view must not contain Cliente B's policies."""
    token_a = seed_data["tokens"]["cliente_a"]
    poliza_a = seed_data["poliza_a"]
    poliza_b = seed_data["poliza_b"]

    async with make_client(token_a) as client:
        response = await client.get("/api/v1/polizas")
        assert response.status_code == 200, response.text
        data = response.json()

        returned_ids = [p["id"] for p in data]
        assert str(poliza_a.id) in returned_ids, "La póliza de Cliente A debe figurar en su lista."
        assert str(poliza_b.id) not in returned_ids, (
            "Violación BOLA: La póliza de Cliente B se filtró en la consulta de Cliente A!"
        )


async def test_cliente_no_puede_acceder_a_poliza_ajena_por_id(seed_data: dict):
    """Anti-BOLA: Direct access to another client's policy must return 404."""
    token_a = seed_data["tokens"]["cliente_a"]
    poliza_b = seed_data["poliza_b"]

    async with make_client(token_a) as client:
        # Client A requests Client B's policy
        response = await client.get(f"/api/v1/polizas/{poliza_b.id}")
        assert response.status_code == 404, (
            f"Esperado 404 para ocultar existencia de objeto ajeno, se obtuvo {response.status_code}"
        )


async def test_cliente_no_puede_acceder_a_deducibles_ajenos(seed_data: dict):
    """Anti-BOLA: Querying deductibles of another client's policy must return 404."""
    token_a = seed_data["tokens"]["cliente_a"]
    poliza_b = seed_data["poliza_b"]

    async with make_client(token_a) as client:
        response = await client.get(f"/api/v1/polizas/{poliza_b.id}/deducibles")
        assert response.status_code == 404


async def test_cliente_no_puede_acceder_a_vehiculo_ajeno(seed_data: dict):
    """Anti-BOLA: Querying another client's vehicle must return 404."""
    token_a = seed_data["tokens"]["cliente_a"]
    vehiculo_b = seed_data["vehiculo_b"]

    async with make_client(token_a) as client:
        response = await client.get(f"/api/v1/vehiculos/{vehiculo_b.id}")
        assert response.status_code == 404


async def test_admin_puede_ver_todas_las_polizas(seed_data: dict):
    """Corporate users (admin) have global visibility across all tenants."""
    admin_token = seed_data["tokens"]["admin"]
    poliza_a = seed_data["poliza_a"]
    poliza_b = seed_data["poliza_b"]

    async with make_client(admin_token) as client:
        response = await client.get("/api/v1/polizas")
        assert response.status_code == 200
        data = response.json()
        returned_ids = [p["id"] for p in data]
        assert str(poliza_a.id) in returned_ids
        assert str(poliza_b.id) in returned_ids
