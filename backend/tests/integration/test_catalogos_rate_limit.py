"""Pruebas de integración para rate limiting y cabeceras de caché en catálogos públicos."""

import pytest

from app.core.rate_limit import rate_limiter
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_catalogos_cache_control_headers(db_session):
    """Verify that public catalog endpoints include Cache-Control headers."""
    async with make_client() as client:
        res_t = await client.get("/api/v1/talleres")
        assert res_t.status_code == 200
        assert res_t.headers.get("Cache-Control") == "public, max-age=300"

        res_a = await client.get("/api/v1/asistencias")
        assert res_a.status_code == 200
        assert res_a.headers.get("Cache-Control") == "public, max-age=300"


async def test_catalogos_rate_limit_exceeded_triggers_429(db_session):
    """Verify that hammering catalog endpoints from the same IP returns HTTP 429."""
    client_ip = "198.51.100.22"
    headers = {"X-Real-IP": client_ip}

    async with make_client() as client:
        for _ in range(60):
            rate_limiter.record_ip(client_ip, endpoint="catalogo")

        res = await client.get("/api/v1/talleres", headers=headers)
        assert res.status_code == 429
        assert "Límite de peticiones por IP excedido" in res.json()["detail"]
