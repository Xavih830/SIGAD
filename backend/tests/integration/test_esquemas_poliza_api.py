"""Pruebas de integración para la API de esquemas de póliza dinámicos."""

import uuid

import pytest

from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_crear_y_listar_esquemas_poliza(base_scenario: ScenarioBundle):
    """Admin crea un esquema de póliza dinámico, lo lista y consulta su detalle."""
    token_admin = base_scenario.admin_token

    payload_esquema = {
        "codigo": "TEST_PESADOS_CARGA",
        "nombre": "Póliza Carga Pesada Test",
        "descripcion": "Esquema dinámico para vehículos de carga pesada.",
        "campos": [
            {"nombre": "tipo_carga", "tipo": "texto", "es_obligatorio": True, "orden": 1},
            {"nombre": "dispositivo_gps", "tipo": "booleano", "es_obligatorio": True, "orden": 2},
            {"nombre": "radio_operacion_km", "tipo": "decimal", "es_obligatorio": False, "orden": 3},
        ],
    }

    async with make_client(token_admin) as client:
        # 1. Crear versión 1
        res_post = await client.post("/api/v1/esquemas-poliza", json=payload_esquema)
        assert res_post.status_code == 201, res_post.text
        data = res_post.json()
        assert data["codigo"] == "TEST_PESADOS_CARGA"
        assert data["version"] == 1
        assert data["es_activo"] is False
        assert len(data["campos"]) == 3
        esquema_id = data["id"]

        # 2. Listar
        res_get = await client.get("/api/v1/esquemas-poliza")
        assert res_get.status_code == 200
        items = res_get.json()
        codigos = [item["codigo"] for item in items]
        assert "TEST_PESADOS_CARGA" in codigos

        # 3. Detalle por ID
        res_detail = await client.get(f"/api/v1/esquemas-poliza/{esquema_id}")
        assert res_detail.status_code == 200
        detail = res_detail.json()
        assert detail["id"] == esquema_id
        assert detail["nombre"] == "Póliza Carga Pesada Test"


async def test_versionamiento_y_activacion_esquema_poliza(base_scenario: ScenarioBundle):
    """Crear el mismo código crea versión 2 inactiva; activar versión conmuta el estado."""
    token_admin = base_scenario.admin_token

    payload_v1 = {
        "codigo": "TEST_VERSIONES",
        "nombre": "Versión 1",
        "campos": [{"nombre": "campo_a", "tipo": "texto", "es_obligatorio": False, "orden": 1}],
    }
    payload_v2 = {
        "codigo": "TEST_VERSIONES",
        "nombre": "Versión 2",
        "campos": [{"nombre": "campo_b", "tipo": "numero", "es_obligatorio": False, "orden": 1}],
    }

    async with make_client(token_admin) as client:
        res1 = await client.post("/api/v1/esquemas-poliza", json=payload_v1)
        assert res1.status_code == 201
        v1_id = res1.json()["id"]
        assert res1.json()["version"] == 1

        res2 = await client.post("/api/v1/esquemas-poliza", json=payload_v2)
        assert res2.status_code == 201
        v2_id = res2.json()["id"]
        assert res2.json()["version"] == 2

        # Activar versión 1
        res_act1 = await client.patch(f"/api/v1/esquemas-poliza/{v1_id}/activar")
        assert res_act1.status_code == 200
        assert res_act1.json()["es_activo"] is True

        # Activar versión 2 -> desactiva versión 1
        res_act2 = await client.patch(f"/api/v1/esquemas-poliza/{v2_id}/activar")
        assert res_act2.status_code == 200
        assert res_act2.json()["es_activo"] is True

        res_check1 = await client.get(f"/api/v1/esquemas-poliza/{v1_id}")
        assert res_check1.json()["es_activo"] is False


async def test_validacion_fail_fast_campos_adicionales_en_poliza(base_scenario: ScenarioBundle):
    """Emisión de póliza valida Fail-Fast campos obligatorios y tipos contra el esquema."""
    token_admin = base_scenario.admin_token
    cliente_id = str(base_scenario.cliente_a.id)
    vehiculo_id = str(base_scenario.vehiculo_a.id)

    payload_esquema = {
        "codigo": "TEST_FAIL_FAST_SCH",
        "nombre": "Esquema Fail-Fast Test",
        "campos": [
            {"nombre": "gps_obligatorio", "tipo": "booleano", "es_obligatorio": True, "orden": 1},
            {"nombre": "tonelaje", "tipo": "decimal", "es_obligatorio": False, "orden": 2},
        ],
    }

    async with make_client(token_admin) as client:
        # Crear esquema
        res_sch = await client.post("/api/v1/esquemas-poliza", json=payload_esquema)
        assert res_sch.status_code == 201
        esquema_id = res_sch.json()["id"]

        poliza_base = {
            "numero_poliza": f"POL-FF-{uuid.uuid4().hex[:6].upper()}",
            "cliente_id": cliente_id,
            "vehiculo_id": vehiculo_id,
            "fecha_inicio": "2026-04-01",
            "fecha_fin": "2027-04-01",
            "valor_asegurado": 30000.0,
            "prima_mensual": 80.0,
            "kilometraje_emision": 12000,
            "esquema_id": esquema_id,
        }

        # 1. Falta campo obligatorio 'gps_obligatorio' -> 422
        bad_payload_missing = {
            **poliza_base,
            "campos_adicionales": {"tonelaje": 15.5},
        }
        res_fail1 = await client.post("/api/v1/polizas", json=bad_payload_missing)
        assert res_fail1.status_code == 422, res_fail1.text
        assert "gps_obligatorio" in res_fail1.text

        # 2. Tipo inválido en decimal 'tonelaje' -> 422
        bad_payload_type = {
            **poliza_base,
            "campos_adicionales": {
                "gps_obligatorio": True,
                "tonelaje": "quince_toneladas_no_numero",
            },
        }
        res_fail2 = await client.post("/api/v1/polizas", json=bad_payload_type)
        assert res_fail2.status_code == 422, res_fail2.text
        assert "tonelaje" in res_fail2.text

        # 3. Payload correcto con campos válidos -> 201 Created
        good_payload = {
            **poliza_base,
            "campos_adicionales": {
                "gps_obligatorio": True,
                "tonelaje": 15.5,
            },
        }
        res_ok = await client.post("/api/v1/polizas", json=good_payload)
        assert res_ok.status_code == 201, res_ok.text
        created = res_ok.json()
        assert created["esquema_id"] == esquema_id
        assert created["campos_adicionales"]["gps_obligatorio"] is True
        assert created["campos_adicionales"]["tonelaje"] == 15.5
