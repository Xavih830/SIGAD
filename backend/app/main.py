import os
from fastapi import FastAPI

from app.api.v1.api import api_router
from app.core.handlers import register_handlers


def create_app() -> FastAPI:
    """FastAPI application factory supporting production docs blocking."""
    is_production = os.getenv("ENVIRONMENT") == "production"

    application = FastAPI(
        title="SIGAD API",
        description="Sistema Integral de Gestión de Asegurados — Backend",
        version="0.1.0",
        docs_url=None if is_production else "/docs",
        redoc_url=None if is_production else "/redoc",
        openapi_url=None if is_production else "/openapi.json",
    )

    # Register global exception handlers (SQLAlchemyError → no PII in logs)
    register_handlers(application)

    # Mount API v1 routes
    application.include_router(api_router)

    @application.get("/health", tags=["Infra"])
    async def health() -> dict:
        """Simple health check for Docker / load-balancer probes."""
        return {"status": "ok"}

    return application


app = create_app()
