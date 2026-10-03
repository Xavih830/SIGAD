"""Integration tests for Documentos API: Anti-IDOR security controls and upload validation.

Verification Gate:
  1. test_idor_documentos: Strict prevention of horizontal privilege escalation (Anti-IDOR).
  2. test_subida_documento_tamano_excedido_413: HTTP 413 for payloads > 15MB.
  3. test_subida_documento_maximo_paginas_400: HTTP 400 for PDFs > 10 pages.
  4. test_subida_y_consulta_documento: Valid creation and status query.
"""

import io
import os
import tempfile
import uuid
import pytest
import pypdfium2 as pdfium
from sqlalchemy import text

from app.models.documento import Documento
from tests.factories import DEFAULT_CAMPOS_EXTRAIDOS, revision_documento_payload
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


def _generar_pdf_bytes(num_paginas: int = 1) -> bytes:
    """Generate in-memory PDF with specified number of pages."""
    pdf = pdfium.PdfDocument.new()
    for _ in range(num_paginas):
        pdf.new_page(width=595, height=842)
    buf = io.BytesIO()
    pdf.save(buf)
    pdf.close()
    return buf.getvalue()


async def test_idor_documentos(base_scenario: ScenarioBundle, db_session):
    """Anti-IDOR: Cliente B no puede descargar documentos asociados a la póliza de Cliente A (HTTP 403)."""
    admin_token = base_scenario.admin_token
    token_a = base_scenario.token_a
    token_b = base_scenario.token_b
    poliza_a = base_scenario.poliza_a

    # 1. Crear archivo físico temporal y registro de documento asociado a poliza_a
    from app.services.storage_service import storage_service
    pdf_content = _generar_pdf_bytes(1)
    ruta_fisica, sha_hash, tamano, _ = storage_service.save_file(
        content=pdf_content,
        filename="cedula_cliente_a.pdf",
        mime_type="application/pdf",
    )

    doc_id = uuid.uuid4()
    await db_session.execute(
        text(
            """
            INSERT INTO documentos (
                id, poliza_id, nombre_archivo, ruta_archivo, tipo_mime, tamano_bytes, hash_sha256,
                estado_extraccion, intentos, created_at, updated_at
            ) VALUES (
                :id, :poliza_id, 'cedula_cliente_a.pdf', :ruta, 'application/pdf', :tamano, :hash,
                'pendiente', 0, NOW(), NOW()
            )
            """
        ),
        {
            "id": doc_id,
            "poliza_id": poliza_a.id,
            "ruta": ruta_fisica,
            "tamano": tamano,
            "hash": sha_hash,
        },
    )
    await db_session.commit()

    # 2. Intento de descarga por CLIENTE B (No autorizado -> Debe retornar 404 Not Found anti-IDOR o 403)
    async with make_client(token_b) as client_b:
        res_b = await client_b.get(f"/api/v1/documentos/{doc_id}/descargar")
        assert res_b.status_code in (403, 404), f"Se esperaba 403 o 404 pero se obtuvo {res_b.status_code}: {res_b.text}"

    # 3. Descarga por CLIENTE A (Dueño legítimo de poliza_a -> HTTP 200)
    async with make_client(token_a) as client_a:
        res_a = await client_a.get(f"/api/v1/documentos/{doc_id}/descargar")
        assert res_a.status_code == 200
        assert len(res_a.content) == tamano

    # 4. Descarga por ADMIN (Acceso global -> HTTP 200)
    async with make_client(admin_token) as client_admin:
        res_admin = await client_admin.get(f"/api/v1/documentos/{doc_id}/descargar")
        assert res_admin.status_code == 200
        assert len(res_admin.content) == tamano

    # 5. Descarga anónima sin token -> HTTP 401 o 403 No autorizado
    async with make_client(None) as client_anon:
        res_anon = await client_anon.get(f"/api/v1/documentos/{doc_id}/descargar")
        assert res_anon.status_code in (401, 403)



async def test_subida_documento_tamano_excedido_413(base_scenario: ScenarioBundle):
    """Archivos mayores a 15 MB deben ser rechazados con HTTP 413 Payload Too Large."""
    admin_token = base_scenario.admin_token
    # 15.5 MB payload
    contenido_gigante = b"X" * (15 * 1024 * 1024 + 500 * 1024)

    async with make_client(admin_token) as client:
        res = await client.post(
            "/api/v1/documentos",
            files={"file": ("archivo_enorme.pdf", contenido_gigante, "application/pdf")},
        )
        assert res.status_code == 413, f"Se esperaba 413 pero se obtuvo {res.status_code}: {res.text}"


async def test_subida_documento_maximo_paginas_400(base_scenario: ScenarioBundle):
    """PDFs con más de 10 páginas deben ser rechazados con HTTP 400 Bad Request."""
    admin_token = base_scenario.admin_token
    pdf_11_paginas = _generar_pdf_bytes(11)

    async with make_client(admin_token) as client:
        res = await client.post(
            "/api/v1/documentos",
            files={"file": ("muchas_paginas.pdf", pdf_11_paginas, "application/pdf")},
        )
        assert res.status_code == 400
        assert "10 páginas" in res.json()["detail"]


async def test_subida_y_consulta_documento_valido(base_scenario: ScenarioBundle):
    """Carga exitosa de documento válido retorna HTTP 201 y estado pendiente."""
    admin_token = base_scenario.admin_token
    pdf_2_paginas = _generar_pdf_bytes(2)

    async with make_client(admin_token) as client:
        res = await client.post(
            "/api/v1/documentos",
            files={"file": ("matricula_valida.pdf", pdf_2_paginas, "application/pdf")},
        )
        assert res.status_code == 201, res.text
        doc_data = res.json()
        assert doc_data["nombre_archivo"] == "matricula_valida.pdf"
        assert doc_data["estado_extraccion"] == "pendiente"
        assert doc_data["paginas"] == 2
        doc_id = doc_data["id"]

        # Consultar documento por ID
        res_get = await client.get(f"/api/v1/documentos/{doc_id}")
        assert res_get.status_code == 200
        assert res_get.json()["estado_extraccion"] == "pendiente"


async def test_revisar_campos_documento_exitoso(base_scenario: ScenarioBundle, db_session):
    """Admin o Agente puede revisar y corregir campos extraídos OCR (HU-06)."""
    admin_token = base_scenario.admin_token
    doc_id = uuid.uuid4()
    res_id = uuid.uuid4()

    await db_session.execute(
        text(
            """
            INSERT INTO documentos (
                id, poliza_id, nombre_archivo, ruta_archivo, tipo_mime, tamano_bytes, hash_sha256,
                estado_extraccion, intentos, created_at, updated_at
            ) VALUES (
                :id, NULL, 'contrato_ocr.pdf', '/tmp/fake.pdf', 'application/pdf', 1024, 'dummyhash',
                'requiere_revision_manual', 1, NOW(), NOW()
            )
            """
        ),
        {"id": doc_id},
    )
    await db_session.execute(
        text(
            """
            INSERT INTO resultados_extraccion (
                id, documento_id, texto_completo, metodo, confianza, campos_extraidos, created_at
            ) VALUES (
                :id, :doc_id, 'Texto con errores', 'pdfplumber', 75.50, '{"placa": "PBX-0000", "valor_asegurado": "12000"}', NOW()
            )
            """
        ),
        {"id": res_id, "doc_id": doc_id},
    )
    await db_session.commit()

    # 1. Ejecutar PATCH /revision con nuevos campos corregidos
    async with make_client(admin_token) as client:
        payload = revision_documento_payload()
        res = await client.patch(f"/api/v1/documentos/{doc_id}/revision", json=payload)
        assert res.status_code == 200, res.text
        data = res.json()
        assert data["id"] == str(doc_id)
        assert data["estado_extraccion"] == "completado"
        assert data["campos_extraidos"]["placa"] == DEFAULT_CAMPOS_EXTRAIDOS["placa"]
        assert data["campos_extraidos"]["valor_asegurado"] == DEFAULT_CAMPOS_EXTRAIDOS["valor_asegurado"]

        # 2. Consultar GET /documentos/{id} para confirmar persistencia en BD
        res_get = await client.get(f"/api/v1/documentos/{doc_id}")
        assert res_get.status_code == 200
        get_data = res_get.json()
        assert get_data["estado_extraccion"] == "completado"
        assert get_data["resultado"]["campos_extraidos"]["placa"] == DEFAULT_CAMPOS_EXTRAIDOS["placa"]
        assert get_data["resultado"]["campos_extraidos"]["numero_poliza"] == DEFAULT_CAMPOS_EXTRAIDOS["numero_poliza"]


async def test_revisar_campos_documento_prohibido_cliente(base_scenario: ScenarioBundle, db_session):
    """Clientes no tienen autorización para revisar o alterar campos OCR (HTTP 403)."""
    token_cliente = base_scenario.token_a
    doc_id = uuid.uuid4()
    res_id = uuid.uuid4()

    await db_session.execute(
        text(
            """
            INSERT INTO documentos (
                id, poliza_id, nombre_archivo, ruta_archivo, tipo_mime, tamano_bytes, hash_sha256,
                estado_extraccion, intentos, created_at, updated_at
            ) VALUES (
                :id, NULL, 'doc_test.pdf', '/tmp/fake.pdf', 'application/pdf', 1024, 'dummyhash',
                'requiere_revision_manual', 1, NOW(), NOW()
            )
            """
        ),
        {"id": doc_id},
    )
    await db_session.execute(
        text(
            """
            INSERT INTO resultados_extraccion (
                id, documento_id, texto_completo, metodo, confianza, campos_extraidos, created_at
            ) VALUES (
                :id, :doc_id, 'Texto prueba', 'pdfplumber', 80.00, '{"placa": "XYZ-9999"}', NOW()
            )
            """
        ),
        {"id": res_id, "doc_id": doc_id},
    )
    await db_session.commit()

    async with make_client(token_cliente) as client:
        res = await client.patch(
            f"/api/v1/documentos/{doc_id}/revision",
            json={"campos_extraidos": {"placa": "HACK-000"}, "estado_extraccion": "completado"},
        )
        assert res.status_code == 403
        assert "Solo administradores y agentes" in res.json()["detail"]


async def test_revisar_campos_documento_estado_invalido_422(base_scenario: ScenarioBundle, db_session):
    """Enviar un estado de extracción no permitido retorna HTTP 422 Unprocessable Entity."""
    admin_token = base_scenario.admin_token
    doc_id = uuid.uuid4()
    res_id = uuid.uuid4()

    await db_session.execute(
        text(
            """
            INSERT INTO documentos (
                id, poliza_id, nombre_archivo, ruta_archivo, tipo_mime, tamano_bytes, hash_sha256,
                estado_extraccion, intentos, created_at, updated_at
            ) VALUES (
                :id, NULL, 'doc_test_422.pdf', '/tmp/fake.pdf', 'application/pdf', 1024, 'dummyhash',
                'pendiente', 0, NOW(), NOW()
            )
            """
        ),
        {"id": doc_id},
    )
    await db_session.execute(
        text(
            """
            INSERT INTO resultados_extraccion (
                id, documento_id, texto_completo, metodo, confianza, campos_extraidos, created_at
            ) VALUES (
                :id, :doc_id, 'Texto prueba', 'pdfplumber', 80.00, '{}', NOW()
            )
            """
        ),
        {"id": res_id, "doc_id": doc_id},
    )
    await db_session.commit()

    async with make_client(admin_token) as client:
        res = await client.patch(
            f"/api/v1/documentos/{doc_id}/revision",
            json={"campos_extraidos": {}, "estado_extraccion": "estado_invalido_xyz"},
        )
        assert res.status_code == 422
        assert "Estado de extracción inválido" in res.json()["detail"]


async def test_revisar_campos_documento_no_encontrado_404(base_scenario: ScenarioBundle):
    """Revisión de documento inexistente retorna HTTP 404 Not Found."""
    admin_token = base_scenario.admin_token
    fake_id = uuid.uuid4()

    async with make_client(admin_token) as client:
        res = await client.patch(
            f"/api/v1/documentos/{fake_id}/revision",
            json={"campos_extraidos": {"placa": "ABC-1234"}},
        )
        assert res.status_code == 404
