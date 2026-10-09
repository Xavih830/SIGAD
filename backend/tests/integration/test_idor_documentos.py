"""Pruebas de integración para controles de seguridad Anti-IDOR en Documentos API."""

import io
import uuid
import pytest
import pypdfium2 as pdfium
from sqlalchemy import text

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


async def _crear_documento_en_bd(db_session, poliza_id: uuid.UUID, nombre_archivo: str = "documento_test.pdf"):
    """Helper factory to insert a physical document and its corresponding database record."""
    from app.services.storage_service import storage_service
    pdf_content = _generar_pdf_bytes(1)
    ruta_fisica, sha_hash, tamano, _ = storage_service.save_file(
        content=pdf_content,
        filename=nombre_archivo,
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
                :id, :poliza_id, :nombre, :ruta, 'application/pdf', :tamano, :hash,
                'pendiente', 0, NOW(), NOW()
            )
            """
        ),
        {
            "id": doc_id,
            "poliza_id": poliza_id,
            "nombre": nombre_archivo,
            "ruta": ruta_fisica,
            "tamano": tamano,
            "hash": sha_hash,
        },
    )
    await db_session.commit()
    return doc_id, tamano


async def test_cliente_no_puede_descargar_documento_ajeno_retorna_404(base_scenario: ScenarioBundle, db_session):
    """Anti-IDOR: Cliente B no puede descargar documentos asociados a la póliza de Cliente A."""
    token_b = base_scenario.token_b
    poliza_a = base_scenario.poliza_a

    doc_id, _ = await _crear_documento_en_bd(db_session, poliza_a.id, "cedula_privada_a.pdf")

    async with make_client(token_b) as client_b:
        res_b = await client_b.get(f"/api/v1/documentos/{doc_id}/descargar")
        assert res_b.status_code in (403, 404), (
            f"IDOR detectado: Se esperaba 403 o 404 pero se obtuvo {res_b.status_code}: {res_b.text}"
        )


async def test_cliente_no_puede_consultar_metadatos_documento_ajeno(base_scenario: ScenarioBundle, db_session):
    """Anti-IDOR: Cliente B no puede consultar información o estado OCR de documentos de Cliente A."""
    token_b = base_scenario.token_b
    poliza_a = base_scenario.poliza_a

    doc_id, _ = await _crear_documento_en_bd(db_session, poliza_a.id, "matricula_privada_a.pdf")

    async with make_client(token_b) as client_b:
        res_b = await client_b.get(f"/api/v1/documentos/{doc_id}")
        assert res_b.status_code in (403, 404), (
            f"Fuga de información IDOR: Se esperaba 403 o 404 pero se obtuvo {res_b.status_code}"
        )


async def test_agente_puede_acceder_documentos_de_asegurados(base_scenario: ScenarioBundle, db_session):
    """El rol AGENTE tiene permisos operativos legítimos para consultar y descargar documentos."""
    agente_token = base_scenario.agente_token
    poliza_a = base_scenario.poliza_a

    doc_id, tamano = await _crear_documento_en_bd(db_session, poliza_a.id, "inspeccion_agente.pdf")

    async with make_client(agente_token) as client_agente:
        res_meta = await client_agente.get(f"/api/v1/documentos/{doc_id}")
        assert res_meta.status_code == 200, f"Agente bloqueado en consulta de documento: {res_meta.text}"
        assert res_meta.json()["id"] == str(doc_id)

        res_descarga = await client_agente.get(f"/api/v1/documentos/{doc_id}/descargar")
        assert res_descarga.status_code == 200, f"Agente bloqueado en descarga: {res_descarga.text}"
        assert len(res_descarga.content) == tamano


async def test_admin_puede_acceder_cualquier_documento(base_scenario: ScenarioBundle, db_session):
    """El rol ADMIN tiene acceso global irrestricto de auditoría para todos los documentos."""
    admin_token = base_scenario.admin_token
    poliza_a = base_scenario.poliza_a

    doc_id, tamano = await _crear_documento_en_bd(db_session, poliza_a.id, "documento_global.pdf")

    async with make_client(admin_token) as client_admin:
        res = await client_admin.get(f"/api/v1/documentos/{doc_id}/descargar")
        assert res.status_code == 200
        assert len(res.content) == tamano


async def test_solicitud_anonima_documentos_retorna_401(base_scenario: ScenarioBundle, db_session):
    """Solicitudes sin autenticación deben ser rechazadas con HTTP 401."""
    poliza_a = base_scenario.poliza_a
    doc_id, _ = await _crear_documento_en_bd(db_session, poliza_a.id, "anon_test.pdf")

    async with make_client(None) as client_anon:
        res = await client_anon.get(f"/api/v1/documentos/{doc_id}/descargar")
        assert res.status_code in (401, 403)
