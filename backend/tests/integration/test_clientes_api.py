"""Pruebas de integración para API de Clientes (CRUD, unicidad 409, paginación, búsqueda)."""

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories.helpers import generar_cedula_valida
from tests.factories.payloads import cliente_payload
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_crear_cliente_con_cedula_valida_201(base_scenario: ScenarioBundle):
    """Crear cliente con cédula ecuatoriana válida retorna 201."""
    admin_token = base_scenario.admin_token
    cedula = generar_cedula_valida()
    payload = cliente_payload(identificacion=cedula, nombres="Cliente Cédula Válida")

    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/clientes", json=payload)
        assert res.status_code == 201
        data = res.json()
        assert data["identificacion"] == cedula
        assert data["nombres"] == "Cliente Cédula Válida"
        assert data["codigo_vinculacion"] is not None


async def test_crear_cliente_con_ruc_natural_201(base_scenario: ScenarioBundle):
    """Crear cliente con RUC persona natural retorna 201."""
    admin_token = base_scenario.admin_token
    ruc = "0926687856001"
    payload = cliente_payload(identificacion=ruc, nombres="Persona Natural RUC")

    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/clientes", json=payload)
        assert res.status_code == 201
        assert res.json()["identificacion"] == ruc


async def test_crear_cliente_con_ruc_sociedad_privada_201(base_scenario: ScenarioBundle):
    """Crear cliente con RUC sociedad privada retorna 201."""
    admin_token = base_scenario.admin_token
    ruc = "1790016919001"
    payload = cliente_payload(identificacion=ruc, nombres="Corporación Privada S.A.")

    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/clientes", json=payload)
        assert res.status_code == 201
        assert res.json()["identificacion"] == ruc


async def test_crear_cliente_con_ruc_sociedad_publica_201(base_scenario: ScenarioBundle):
    """Crear cliente con RUC sociedad pública retorna 201."""
    admin_token = base_scenario.admin_token
    ruc = "1760000820001"
    payload = cliente_payload(identificacion=ruc, nombres="Empresa Pública EP")

    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/clientes", json=payload)
        assert res.status_code == 201
        assert res.json()["identificacion"] == ruc


async def test_crear_cliente_identificacion_invalida_422(base_scenario: ScenarioBundle):
    """Cédulas o RUCs inválidos son rechazados con 422."""
    admin_token = base_scenario.admin_token
    payload = cliente_payload(identificacion="1234567890")

    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/clientes", json=payload)
        assert res.status_code == 422


async def test_crear_cliente_identificacion_duplicada_409(base_scenario: ScenarioBundle):
    """Identificación duplicada retorna 409 con mensaje genérico sin filtrar PII."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a

    payload = cliente_payload(identificacion=cliente_a.identificacion, nombres="Intento Duplicado")
    async with make_client(admin_token) as client:
        res = await client.post("/api/v1/clientes", json=payload)
        assert res.status_code == 409
        detail = res.json()["detail"]
        assert "ya existe un cliente" in detail.lower()
        # Verificar que no se filtre la cédula exacta en el mensaje
        assert cliente_a.identificacion not in detail


async def test_listar_clientes_paginado_con_total(base_scenario: ScenarioBundle):
    """GET /clientes retorna PaginatedResponse con items, total, skip y limit."""
    agente_token = base_scenario.agente_token

    async with make_client(agente_token) as client:
        res = await client.get("/api/v1/clientes?skip=0&limit=5")
        assert res.status_code == 200
        data = res.json()
        assert "items" in data
        assert "total" in data
        assert data["skip"] == 0
        assert data["limit"] == 5
        assert isinstance(data["items"], list)
        assert data["total"] >= len(data["items"])


async def test_buscar_cliente_por_nombre_parcial(base_scenario: ScenarioBundle):
    """Búsqueda por query param 'q' encuentra coincidencias por nombre."""
    admin_token = base_scenario.admin_token
    nombre_unico = f"BusquedaNombre_{uuid.uuid4().hex[:6]}"
    cedula = generar_cedula_valida()
    payload = cliente_payload(identificacion=cedula, nombres=nombre_unico)

    async with make_client(admin_token) as client:
        await client.post("/api/v1/clientes", json=payload)

        # Buscar con parte del nombre
        res = await client.get(f"/api/v1/clientes?q={nombre_unico[:10]}")
        assert res.status_code == 200
        items = res.json()["items"]
        assert any(c["nombres"] == nombre_unico for c in items)


async def test_buscar_cliente_por_identificacion_parcial(base_scenario: ScenarioBundle):
    """Búsqueda por query param 'q' encuentra coincidencias por identificación."""
    admin_token = base_scenario.admin_token
    cedula = generar_cedula_valida()
    payload = cliente_payload(identificacion=cedula, nombres="Busqueda Identificacion")

    async with make_client(admin_token) as client:
        await client.post("/api/v1/clientes", json=payload)

        res = await client.get(f"/api/v1/clientes?q={cedula}")
        assert res.status_code == 200
        items = res.json()["items"]
        assert any(c["identificacion"] == cedula for c in items)


async def test_actualizar_cliente_admin_y_agente_200(base_scenario: ScenarioBundle, db_session: AsyncSession):
    """ADMIN y AGENTE pueden actualizar datos de contacto con PATCH."""
    from app.core.security import create_access_token
    from app.models.usuario import RolEnum
    from tests.factories.models import create_user

    admin_token = base_scenario.admin_token
    agente = await create_user(
        db_session,
        email=f"agente_patch_{uuid.uuid4().hex[:6]}@test.sigad.ec",
        nombre="Agente Patch",
        rol=RolEnum.AGENTE,
    )
    agente_token = create_access_token({"sub": str(agente.id)})

    # 1. Crear cliente con admin
    cedula = generar_cedula_valida()
    payload = cliente_payload(identificacion=cedula, nombres="Nombre Original", telefono="0991111111")
    async with make_client(admin_token) as client:
        c_res = await client.post("/api/v1/clientes", json=payload)
        cliente_id = c_res.json()["id"]

    # 2. Actualizar con agente
    async with make_client(agente_token) as client:
        update_res = await client.patch(
            f"/api/v1/clientes/{cliente_id}",
            json={"nombres": "Nombre Actualizado por Agente", "telefono": "0992222222"},
        )
        assert update_res.status_code == 200
        updated = update_res.json()
        assert updated["nombres"] == "Nombre Actualizado por Agente"
        assert updated["telefono"] == "0992222222"
        assert updated["identificacion"] == cedula


async def test_actualizar_cliente_no_modifica_identificacion(base_scenario: ScenarioBundle):
    """Intentar modificar identificacion mediante PATCH es rechazado por strict schema."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a

    async with make_client(admin_token) as client:
        res = await client.patch(
            f"/api/v1/clientes/{cliente_a.id}",
            json={"identificacion": "0926687856"},
        )
        assert res.status_code == 422


async def test_eliminar_cliente_sin_registros_por_admin_204(base_scenario: ScenarioBundle):
    """ADMIN puede eliminar un cliente sin pólizas ni vehículos (204)."""
    admin_token = base_scenario.admin_token
    cedula = generar_cedula_valida()
    payload = cliente_payload(identificacion=cedula, nombres="Cliente Solitario")

    async with make_client(admin_token) as client:
        c_res = await client.post("/api/v1/clientes", json=payload)
        cliente_id = c_res.json()["id"]

        del_res = await client.delete(f"/api/v1/clientes/{cliente_id}")
        assert del_res.status_code == 204

        # Comprobar que ya no existe (404)
        get_res = await client.get(f"/api/v1/clientes/{cliente_id}")
        assert get_res.status_code == 404


async def test_eliminar_cliente_con_polizas_retorna_409(base_scenario: ScenarioBundle):
    """Eliminar un cliente con pólizas asociadas falla con 409 conflicto."""
    admin_token = base_scenario.admin_token
    cliente_a = base_scenario.cliente_a  # cliente_a tiene poliza_a asociada en base_scenario

    async with make_client(admin_token) as client:
        del_res = await client.delete(f"/api/v1/clientes/{cliente_a.id}")
        assert del_res.status_code == 409
        assert "registros asociados" in del_res.json()["detail"].lower()


async def test_eliminar_cliente_por_agente_retorna_403(base_scenario: ScenarioBundle, db_session: AsyncSession):
    """Un usuario con rol AGENTE no puede eliminar clientes (403 Forbidden)."""
    from app.core.security import create_access_token
    from app.models.usuario import RolEnum
    from tests.factories.models import create_user

    agente = await create_user(
        db_session,
        email=f"agente_delete_{uuid.uuid4().hex[:6]}@test.sigad.ec",
        nombre="Agente Delete",
        rol=RolEnum.AGENTE,
    )
    agente_token = create_access_token({"sub": str(agente.id)})
    cliente_a = base_scenario.cliente_a

    async with make_client(agente_token) as client:
        del_res = await client.delete(f"/api/v1/clientes/{cliente_a.id}")
        assert del_res.status_code == 403


async def test_cliente_no_encontrado_retorna_404(base_scenario: ScenarioBundle):
    """IDs inexistentes retornan 404 en GET, PATCH y DELETE."""
    admin_token = base_scenario.admin_token
    fake_id = uuid.uuid4()

    async with make_client(admin_token) as client:
        get_res = await client.get(f"/api/v1/clientes/{fake_id}")
        assert get_res.status_code == 404

        patch_res = await client.patch(
            f"/api/v1/clientes/{fake_id}",
            json={"nombres": "Fantasma"},
        )
        assert patch_res.status_code == 404

        del_res = await client.delete(f"/api/v1/clientes/{fake_id}")
        assert del_res.status_code == 404
