"""Test de verificación de perímetro estricto contra inyecciones y Mass Assignment."""

import httpx
import pytest

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_rechazo_inyeccion_campos_extra_mass_assignment(client: httpx.AsyncClient, seed_data: dict):
    """Verifica que un intento de inyectar campos no declarados es rechazado con 422."""
    agente_token = seed_data["agente_token"]
    headers = {"Authorization": f"Bearer {agente_token}"}

    # Inyección de campo 'rol' y 'is_admin' en registro de cliente
    payload_malicioso = {
        "identificacion": "0926687856",
        "nombres": "Cliente Legitimo",
        "email": "test.inyeccion@sigad.ec",
        "telefono": "0987654321",
        "rol": "admin",          # Campo extra inyectado
        "is_admin": True,        # Campo extra inyectado
    }

    res = await client.post("/api/v1/clientes", json=payload_malicioso, headers=headers)
    assert res.status_code == 422, "Pydantic con extra='forbid' debe retornar HTTP 422."
    errores = res.json().get("detail", [])
    campos_rechazados = [e.get("loc", [])[-1] for e in errores if e.get("type") == "extra_forbidden"]
    assert "rol" in campos_rechazados
    assert "is_admin" in campos_rechazados


async def test_rechazo_ruta_duplicada_cargar(client: httpx.AsyncClient, seed_data: dict):
    """Verifica que la ruta obsoleta /documentos/cargar ya no existe (retorna 404/405)."""
    agente_token = seed_data["agente_token"]
    headers = {"Authorization": f"Bearer {agente_token}"}
    files = {"file": ("test.pdf", b"%PDF-1.4...", "application/pdf")}

    res = await client.post("/api/v1/documentos/cargar", files=files, headers=headers)
    assert res.status_code in [404, 405], "La ruta duplicada /documentos/cargar debe estar eliminada."


async def test_rechazo_subida_sin_content_type(client: httpx.AsyncClient, seed_data: dict):
    """Verifica que un archivo sin MIME type sea rechazado con 422 (Fail-Fast sin fallback)."""
    agente_token = seed_data["agente_token"]
    headers = {"Authorization": f"Bearer {agente_token}"}
    # Enviar archivo sin tipo MIME explícito
    files = {"file": ("test.pdf", b"%PDF-1.4...", "")}

    res = await client.post("/api/v1/documentos", files=files, headers=headers)
    assert res.status_code == 422, "Archivo sin Content-Type debe ser rechazado con 422."


async def test_rechazo_coercion_implicita_tipos_strict_mode(client: httpx.AsyncClient, seed_data: dict):
    """Verifica que strict=True rechace coerción implícita de tipos (ej. string en campo entero)."""
    agente_token = seed_data["agente_token"]
    headers = {"Authorization": f"Bearer {agente_token}"}

    payload_coercion = {
        "placa": "PBX-1234",
        "marca": "Chevrolet",
        "modelo": "Sail",
        "anio": "2024",  # String en vez de int
        "cliente_id": str(seed_data["cliente_a"].id),
    }

    res = await client.post("/api/v1/vehiculos", json=payload_coercion, headers=headers)
    assert res.status_code == 422, f"Coerción de tipo debe retornar 422, se obtuvo: {res.status_code}"
    errores = res.json().get("detail", [])
    assert any(e.get("loc", [])[-1] == "anio" for e in errores)
