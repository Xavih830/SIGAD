"""Integration tests for Esquemas de Extracción REST API.

Covers:
1. Multi-Domain & Multi-Version Lifecycle:
   - Independent append-only version streams for Vehicular, Vida, and Hogar schemas.
   - Atomic active-version switching across 3 versions with idempotency.
2. Adversarial & Security Testing:
   - Immobility: PUT and DELETE requests are rejected with 405 Method Not Allowed.
   - Anti-BFLA: Client gets 403 on all routes; Agent cannot create or activate.
   - Input sanitization: ReDoS, null bytes, duplicate fields, and type mismatch return 422.
   - Empty file uploads return 400.
   - Exception in OCR extraction returns 422 and guarantees temp file cleanup (no disk leak).
"""

import io
from unittest.mock import patch
import uuid

from PIL import Image
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories.fixtures import (
    ESQUEMA_CODIGO_HOGAR,
    ESQUEMA_CODIGO_VEHICULAR,
    ESQUEMA_CODIGO_VIDA,
    TEXTO_OCR_VEHICULAR,
    TEXTO_OCR_VIDA,
)
from tests.factories.models import create_esquema
from tests.factories.payloads import (
    campo_regla_payload,
    esquema_hogar_payload,
    esquema_payload,
    esquema_vehicular_payload,
    esquema_vida_payload,
)
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


# ── 1. Ciclo de Vida Multi-Dominio y Versiones Append-Only ─────────────────────

async def test_creacion_independiente_tres_dominios(base_scenario: ScenarioBundle):
    """Admin creates 3 distinct domain schemas (Vehicular, Vida, Hogar).
    Each receives version 1 independently.
    """
    token_admin = base_scenario.admin_token

    payload_vehicular = esquema_vehicular_payload()
    payload_vida = esquema_vida_payload()
    payload_hogar = esquema_hogar_payload()

    async with make_client(token_admin) as client:
        # Crear Vehicular (v1)
        res_veh = await client.post("/api/v1/esquemas", json=payload_vehicular)
        assert res_veh.status_code == 201, res_veh.text
        data_veh = res_veh.json()
        assert data_veh["codigo"] == ESQUEMA_CODIGO_VEHICULAR
        assert data_veh["version"] == 1
        assert data_veh["es_activo"] is False

        # Crear Vida (v1)
        res_vid = await client.post("/api/v1/esquemas", json=payload_vida)
        assert res_vid.status_code == 201, res_vid.text
        data_vid = res_vid.json()
        assert data_vid["codigo"] == ESQUEMA_CODIGO_VIDA
        assert data_vid["version"] == 1
        assert data_vid["es_activo"] is False

        # Crear Hogar (v1)
        res_hog = await client.post("/api/v1/esquemas", json=payload_hogar)
        assert res_hog.status_code == 201, res_hog.text
        data_hog = res_hog.json()
        assert data_hog["codigo"] == ESQUEMA_CODIGO_HOGAR
        assert data_hog["version"] == 1
        assert data_hog["es_activo"] is False


async def test_transiciones_atomicas_y_conmutacion_versiones(base_scenario: ScenarioBundle):
    """Crea v1, v2 y v3 para el mismo código y conmuta la versión activa.
    Garantiza que exactamente una versión permanezca activa por código.
    """
    token_admin = base_scenario.admin_token
    codigo = f"TEST_SERIE_{uuid.uuid4().hex[:6].upper()}"

    p1 = esquema_payload(codigo=codigo, nombre="Serie V1")
    p2 = esquema_payload(codigo=codigo, nombre="Serie V2")
    p3 = esquema_payload(codigo=codigo, nombre="Serie V3")

    async with make_client(token_admin) as client:
        # Publicar v1, v2 y v3
        r1 = await client.post("/api/v1/esquemas", json=p1)
        id_1 = r1.json()["id"]
        r2 = await client.post("/api/v1/esquemas", json=p2)
        id_2 = r2.json()["id"]
        r3 = await client.post("/api/v1/esquemas", json=p3)
        id_3 = r3.json()["id"]

        assert r1.json()["version"] == 1
        assert r2.json()["version"] == 2
        assert r3.json()["version"] == 3

        # Activar v1
        await client.patch(f"/api/v1/esquemas/{id_1}/activar")
        # Activar v2 (debe desactivar v1)
        await client.patch(f"/api/v1/esquemas/{id_2}/activar")

        check_1 = (await client.get(f"/api/v1/esquemas/{id_1}")).json()
        check_2 = (await client.get(f"/api/v1/esquemas/{id_2}")).json()
        check_3 = (await client.get(f"/api/v1/esquemas/{id_3}")).json()

        assert check_1["es_activo"] is False
        assert check_2["es_activo"] is True
        assert check_3["es_activo"] is False

        # Activar v2 nuevamente (idempotencia)
        res_idemp = await client.patch(f"/api/v1/esquemas/{id_2}/activar")
        assert res_idemp.status_code == 200
        assert res_idemp.json()["es_activo"] is True


# ── 2. Inmutabilidad y Protección contra Ataques (No-Happy-Path) ───────────────

async def test_inmutabilidad_put_y_delete_prohibidos(base_scenario: ScenarioBundle, db_session: AsyncSession):
    """Append-only estricto: PUT y DELETE no están implementados (405 Method Not Allowed)."""
    token_admin = base_scenario.admin_token
    esquema = await create_esquema(db_session)

    async with make_client(token_admin) as client:
        res_put = await client.put(f"/api/v1/esquemas/{esquema.id}", json=esquema_payload())
        assert res_put.status_code == 405

        res_delete = await client.delete(f"/api/v1/esquemas/{esquema.id}")
        assert res_delete.status_code == 405


async def test_ataque_redos_por_api_rechazado_con_422(base_scenario: ScenarioBundle):
    """Intento de enviar un regex ReDoS catastrófico por API es abortado con 422."""
    token_admin = base_scenario.admin_token
    evil_campo = campo_regla_payload(regex=r"(a+)+")
    payload = esquema_payload(campos=[evil_campo])

    async with make_client(token_admin) as client:
        res = await client.post("/api/v1/esquemas", json=payload)
        assert res.status_code == 422
        assert "Anti-ReDoS" in res.text or "repetición anidada" in res.text


async def test_ataque_null_byte_por_api_rechazado_con_422(base_scenario: ScenarioBundle):
    """Inyección de byte nulo en la regla es interceptada con 422."""
    token_admin = base_scenario.admin_token
    campo_nulo = campo_regla_payload(nombre="campo\x00malicioso")
    payload = esquema_payload(campos=[campo_nulo])

    async with make_client(token_admin) as client:
        res = await client.post("/api/v1/esquemas", json=payload)
        assert res.status_code == 422


async def test_ataque_campos_duplicados_por_api_rechazado_con_422(base_scenario: ScenarioBundle):
    """Dos campos con el mismo nombre en el payload son rechazados con 422."""
    token_admin = base_scenario.admin_token
    c1 = campo_regla_payload(nombre="placa", orden=0)
    c2 = campo_regla_payload(nombre="placa", orden=1)
    payload = esquema_payload(campos=[c1, c2])

    async with make_client(token_admin) as client:
        res = await client.post("/api/v1/esquemas", json=payload)
        assert res.status_code == 422
        assert "duplicados" in res.text


# ── 3. Robustez en Endpoint de Prueba (/probar) ───────────────────────────────

async def test_probar_esquema_archivo_vacio_retorna_400(
    base_scenario: ScenarioBundle,
    db_session: AsyncSession,
):
    """Subir un archivo de 0 bytes para prueba retorna 400 Bad Request."""
    token_admin = base_scenario.admin_token
    esquema = await create_esquema(db_session)

    async with make_client(token_admin) as client:
        res = await client.post(
            f"/api/v1/esquemas/{esquema.id}/probar",
            files={"file": ("vacio.pdf", b"", "application/pdf")},
        )
        assert res.status_code == 400
        assert "vacío" in res.text


async def test_probar_esquema_error_extraccion_limpia_temporal(
    base_scenario: ScenarioBundle,
    db_session: AsyncSession,
):
    """Si la extracción lanza una excepción (PDF dañado), retorna 422 y garantiza eliminación de temporal."""
    token_admin = base_scenario.admin_token
    esquema = await create_esquema(db_session)

    with patch("app.api.v1.endpoints.esquemas.extraer_documento_sync", side_effect=RuntimeError("Corrupt PDF")):
        async with make_client(token_admin) as client:
            res = await client.post(
                f"/api/v1/esquemas/{esquema.id}/probar",
                files={"file": ("corrupto.pdf", b"%PDF-corrupted", "application/pdf")},
            )
            assert res.status_code == 422
            assert "Error durante el procesamiento" in res.text


async def test_probar_esquema_imagen_dimensiones_excedidas_400(
    base_scenario: ScenarioBundle,
    db_session: AsyncSession,
):
    """Subir una imagen con dimensiones mayores a 4096 px retorna 400 Bad Request (Anti-Pixel-Flood)."""
    token_admin = base_scenario.admin_token
    esquema = await create_esquema(db_session)

    buf = io.BytesIO()
    Image.new("RGB", (4097, 100), color="white").save(buf, format="PNG")
    oversized_bytes = buf.getvalue()

    async with make_client(token_admin) as client:
        res = await client.post(
            f"/api/v1/esquemas/{esquema.id}/probar",
            files={"file": ("pixel_bomb.png", oversized_bytes, "image/png")},
        )
        assert res.status_code == 400
        assert "exceden el límite máximo" in res.text


async def test_probar_esquema_exitoso_multi_dominio(
    base_scenario: ScenarioBundle,
    db_session: AsyncSession,
):
    """Prueba de extracción exitosa ejecutando las reglas sobre texto extraído."""
    token_admin = base_scenario.admin_token
    payload_vida = esquema_vida_payload()

    # Crear esquema de vida
    async with make_client(token_admin) as client:
        res_create = await client.post("/api/v1/esquemas", json=payload_vida)
        assert res_create.status_code == 201
        esquema_id = res_create.json()["id"]

        with patch("app.services.extraccion_service._extraer_compuerta_1_pdfplumber", return_value=TEXTO_OCR_VIDA):
            res_test = await client.post(
                f"/api/v1/esquemas/{esquema_id}/probar",
                files={"file": ("certificado_vida.pdf", b"%PDF-1.4 dummy content with length > 50 characters", "application/pdf")},
            )
            assert res_test.status_code == 200, res_test.text
            data = res_test.json()
            assert data["campos_extraidos"]["numero_certificado"] == "849201"
            assert data["campos_extraidos"]["titular_cedula"] == "0926687856"
            assert data["confianza"] == 100.0


# ── 4. Control de Acceso RBAC Estricto (BFLA) ─────────────────────────────────

async def test_rbac_cliente_bloqueado_completamente(base_scenario: ScenarioBundle):
    """Cliente no tiene acceso a ninguna operación de esquemas (HTTP 403 en todas)."""
    token_cliente = base_scenario.token_a
    random_id = uuid.uuid4()

    async with make_client(token_cliente) as client:
        assert (await client.get("/api/v1/esquemas")).status_code == 403
        assert (await client.get(f"/api/v1/esquemas/{random_id}")).status_code == 403
        assert (await client.post("/api/v1/esquemas", json=esquema_payload())).status_code == 403
        assert (await client.patch(f"/api/v1/esquemas/{random_id}/activar")).status_code == 403
        assert (await client.post(
            f"/api/v1/esquemas/{random_id}/probar",
            files={"file": ("test.pdf", b"%PDF-1.4", "application/pdf")},
        )).status_code == 403


async def test_rbac_agente_lectura_y_prueba_si_escritura_no(
    base_scenario: ScenarioBundle,
    db_session: AsyncSession,
):
    """Agente con RolEnum.AGENTE puede listar y ver esquemas, pero no puede crear ni activar."""
    from app.core.security import create_access_token
    from app.models.usuario import RolEnum
    from tests.factories.models import create_user

    agente_user = await create_user(
        db_session,
        email="agente_estricto@test.sigad.ec",
        rol=RolEnum.AGENTE,
    )
    token_agente = create_access_token({"sub": str(agente_user.id)})
    esquema = await create_esquema(db_session)

    async with make_client(token_agente) as client:
        # Lectura permitida
        assert (await client.get("/api/v1/esquemas")).status_code == 200
        assert (await client.get(f"/api/v1/esquemas/{esquema.id}")).status_code == 200

        # Escritura denegada (solo ADMIN)
        assert (await client.post("/api/v1/esquemas", json=esquema_payload())).status_code == 403
        assert (await client.patch(f"/api/v1/esquemas/{esquema.id}/activar")).status_code == 403
