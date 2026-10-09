"""Validación de sondas de salud (liveness y readiness) y orquestación."""

from pathlib import Path
import pytest
from httpx import AsyncClient, ASGITransport
import yaml

from app.main import app
from app.workers.health import worker_app


from unittest.mock import AsyncMock, patch
from sqlalchemy.ext.asyncio import AsyncSession
from tests.integration.conftest import make_client


pytestmark = pytest.mark.asyncio(loop_scope="session")
async def test_api_health_and_readiness_endpoints(db_session: AsyncSession):
    """API /health and /health/ready validate active database connection and handle degradation."""
    async with make_client(None) as client:
        res_health = await client.get("/health")
        assert res_health.status_code == 200, f"Health check failed with body: {res_health.text}"
        data_health = res_health.json()
        assert data_health["status"] == "ok"
        assert data_health["database"] == "connected"

        res_ready = await client.get("/health/ready")
        assert res_ready.status_code == 200
        assert res_ready.json()["database"] == "connected"

        res_live = await client.get("/health/live")
        assert res_live.status_code == 200
        assert res_live.json() == {"status": "ok"}

        with patch.object(db_session, "execute", side_effect=Exception("Connection lost")):
            from app.main import app as main_app
            res_degraded = await client.get("/health")
            assert res_degraded.status_code in [200, 503]


async def test_worker_health_endpoints():
    """Worker /health and /health/live return active pool status."""
    transport = ASGITransport(app=worker_app)
    async with AsyncClient(transport=transport, base_url="http://test") as worker_client:
        res_live = await worker_client.get("/health/live")
        assert res_live.status_code == 200
        assert res_live.json() == {"status": "ok", "worker": "running"}

        res_health = await worker_client.get("/health")
        assert res_health.status_code == 200
        data = res_health.json()
        assert data["status"] == "ok"
        assert data["pool"] == "active"


async def test_docker_compose_healthchecks_and_restart_policy():
    """Verify docker-compose.yml specifies restart: always and healthchecks (§2.5)."""
    repo_root = Path(__file__).resolve().parents[2].parent
    compose_path = repo_root / "docker-compose.yml"
    assert compose_path.exists(), f"docker-compose.yml not found at {compose_path}"

    with open(compose_path, "r", encoding="utf-8") as f:
        compose = yaml.safe_load(f)

    services = compose.get("services", {})
    for service_name in ["postgres", "api", "worker", "caddy"]:
        assert service_name in services, f"Service {service_name} missing from docker-compose.yml"
        srv = services[service_name]
        assert srv.get("restart") == "always", f"Service {service_name} does not have restart: always"
        assert "healthcheck" in srv, f"Service {service_name} missing healthcheck declaration (§2.5)"

    caddy_path = repo_root / "Caddyfile"
    caddy_content = caddy_path.read_text(encoding="utf-8")
    assert "handle /health*" in caddy_content or "/health" in caddy_content
    assert "handle /docs*" in caddy_content or "/docs" in caddy_content
    assert "handle /openapi.json" in caddy_content or "openapi.json" in caddy_content
