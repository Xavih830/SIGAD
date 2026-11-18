"""Pruebas de integración para modificación idempotente de pólizas, historial y cancelación."""

import uuid

import pytest

from tests.factories.payloads import poliza_payload
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def _crear_poliza_base(admin_token: str, scenario: ScenarioBundle) -> dict:
    payload = poliza_payload(
        cliente_id=scenario.cliente_a.id,
        vehiculo_id=scenario.vehiculo_a.id,
        numero_poliza=f"POL-UPD-{uuid.uuid4().hex[:6].upper()}",
    )
    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/polizas", json=payload)
        assert res.status_code == 201, res.text
        return res.json()


async def test_put_poliza_cambio_genera_historial_con_usuario(base_scenario: ScenarioBundle):
    """Un cambio de campo en PUT genera fila en historial_cambios con valor anterior, nuevo y usuario_id."""
    poliza = await _crear_poliza_base(base_scenario.admin_token, base_scenario)
    poliza_id = poliza["id"]

    async with make_client(base_scenario.admin_token) as client:
        put_res = await client.put(
            f"/api/v1/polizas/{poliza_id}",
            json={"prima_mensual": "199.50", "version": poliza["version"]},
        )
        assert put_res.status_code == 200, put_res.text
        updated = put_res.json()
        assert float(updated["prima_mensual"]) == pytest.approx(199.50)
        assert updated["version"] == poliza["version"] + 1

        hist_res = await client.get(f"/api/v1/polizas/{poliza_id}/historial")
        assert hist_res.status_code == 200, hist_res.text
        items = hist_res.json()["items"]
        prima_changes = [i for i in items if i["campo"] == "prima_mensual"]
        assert len(prima_changes) == 1
        assert float(prima_changes[0]["valor_nuevo"]) == pytest.approx(199.50)
        assert prima_changes[0]["usuario_id"] is not None


async def test_put_poliza_idempotente_no_duplica_historial(base_scenario: ScenarioBundle):
    """Enviar el mismo PUT dos veces (sin cambios en la segunda) no genera nuevas filas de historial."""
    poliza = await _crear_poliza_base(base_scenario.admin_token, base_scenario)
    poliza_id = poliza["id"]

    async with make_client(base_scenario.admin_token) as client:
        res1 = await client.put(
            f"/api/v1/polizas/{poliza_id}",
            json={"prima_mensual": "210.00", "version": poliza["version"]},
        )
        assert res1.status_code == 200, res1.text
        v2 = res1.json()["version"]

        hist_after_1 = (await client.get(f"/api/v1/polizas/{poliza_id}/historial")).json()["total"]

        # Segundo PUT con exactamente los mismos valores y la versión actual v2
        res2 = await client.put(
            f"/api/v1/polizas/{poliza_id}",
            json={"prima_mensual": "210.00", "version": v2},
        )
        assert res2.status_code == 200, res2.text
        assert res2.json()["version"] == v2

        hist_after_2 = (await client.get(f"/api/v1/polizas/{poliza_id}/historial")).json()["total"]
        assert hist_after_2 == hist_after_1


async def test_put_poliza_version_desactualizada_rechaza_409(base_scenario: ScenarioBundle):
    """Una versión desactualizada debe responder HTTP 409 Conflict."""
    poliza = await _crear_poliza_base(base_scenario.admin_token, base_scenario)
    poliza_id = poliza["id"]

    async with make_client(base_scenario.admin_token) as client:
        res1 = await client.put(
            f"/api/v1/polizas/{poliza_id}",
            json={"valor_asegurado": "30000.00", "version": poliza["version"]},
        )
        assert res1.status_code == 200

        res_stale = await client.put(
            f"/api/v1/polizas/{poliza_id}",
            json={"valor_asegurado": "35000.00", "version": poliza["version"]},
        )
        assert res_stale.status_code == 409


async def test_cancelar_poliza_no_borra_y_filtra_por_cancelada(base_scenario: ScenarioBundle):
    """Cancelar una póliza no borra el registro y aparece al filtrar por estado=cancelada."""
    poliza = await _crear_poliza_base(base_scenario.admin_token, base_scenario)
    poliza_id = poliza["id"]

    async with make_client(base_scenario.admin_token) as client:
        patch_res = await client.patch(
            f"/api/v1/polizas/{poliza_id}/estado",
            json={"estado": "cancelada"},
        )
        assert patch_res.status_code == 200, patch_res.text
        assert patch_res.json()["estado"] == "cancelada"

        list_res = await client.get("/api/v1/polizas?estado=cancelada&limit=100")
        assert list_res.status_code == 200, list_res.text
        ids = [item["id"] for item in list_res.json()]
        assert poliza_id in ids
