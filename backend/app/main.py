from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.api import api_router
from app.core.config import settings
from app.core.handlers import register_handlers
from app.api.deps import get_db


def create_app() -> FastAPI:
    """FastAPI application factory supporting production docs blocking."""
    is_production = settings.ENVIRONMENT == "production"

    application = FastAPI(
        title="SIGAD API",
        description="Sistema Integral de Gestión de Asegurados — Backend",
        version="0.1.0",
        docs_url=None if is_production else "/docs",
        redoc_url=None if is_production else "/redoc",
        openapi_url=None if is_production else "/openapi.json",
    )

    # CORS Middleware for Web clients
    application.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Register global exception handlers (SQLAlchemyError → no PII in logs)
    register_handlers(application)

    # Mount API v1 routes
    application.include_router(api_router)

    _health_cache = {"status": "unknown", "timestamp": 0.0}
    _CACHE_TTL = 3.0  # segundos

    @application.get("/health/live", tags=["Infra"])
    async def liveness() -> dict[str, str]:
        """Liveness probe: verifies process event-loop responsiveness without hitting DB."""
        return {"status": "ok"}

    @application.get("/health", tags=["Infra"])
    @application.get("/health/ready", tags=["Infra"])
    async def health(db: AsyncSession = Depends(get_db)) -> dict:
        """Deep readiness probe: validates PostgreSQL with bounded timeout and rate-cache (poryecto.md §2.5)."""
        import asyncio
        import time

        now = time.monotonic()
        if now - _health_cache["timestamp"] < _CACHE_TTL and _health_cache["status"] == "connected":
            return {"status": "ok", "database": "connected"}

        try:
            await db.execute(text("SELECT 1"), execution_options={"timeout": 1.0})
            _health_cache["status"] = "connected"
            _health_cache["timestamp"] = now
            return {"status": "ok", "database": "connected"}
        except Exception as e:
            _health_cache["status"] = "disconnected"
            _health_cache["timestamp"] = 0.0
            return JSONResponse(
                status_code=503,
                content={"status": "degraded", "database": "disconnected", "error": str(e)},
            )

    return application


app = create_app()
