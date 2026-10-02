"""TEST: Swagger and OpenAPI schema endpoints are strictly blocked in production.

Verifies that when ENVIRONMENT=production:
- /docs returns HTTP 404
- /redoc returns HTTP 404
- /openapi.json returns HTTP 404
And in development mode, documentation is accessible for developer productivity.
"""

from httpx import ASGITransport, AsyncClient
import pytest

from app.core.config import settings
from app.main import create_app


@pytest.mark.asyncio
async def test_openapi_and_swagger_blocked_in_production(monkeypatch):
    """When ENVIRONMENT is set to 'production', docs endpoints must return 404 Not Found."""
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    prod_app = create_app()
    transport = ASGITransport(app=prod_app)

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        # 1. /docs must return 404
        resp_docs = await client.get("/docs")
        assert resp_docs.status_code == 404, f"Expected 404 for /docs in production, got {resp_docs.status_code}"

        # 2. /redoc must return 404
        resp_redoc = await client.get("/redoc")
        assert resp_redoc.status_code == 404, f"Expected 404 for /redoc in production, got {resp_redoc.status_code}"

        # 3. /openapi.json must return 404
        resp_openapi = await client.get("/openapi.json")
        assert resp_openapi.status_code == 404, f"Expected 404 for /openapi.json in production, got {resp_openapi.status_code}"


@pytest.mark.asyncio
async def test_openapi_and_swagger_exposed_in_development(monkeypatch):
    """When ENVIRONMENT is 'development' or default, docs endpoints must return 200 OK."""
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    dev_app = create_app()
    transport = ASGITransport(app=dev_app)

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        resp_docs = await client.get("/docs")
        assert resp_docs.status_code == 200

        resp_openapi = await client.get("/openapi.json")
        assert resp_openapi.status_code == 200
        data = resp_openapi.json()
        assert "openapi" in data
        assert data["info"]["title"] == "SIGAD API"
