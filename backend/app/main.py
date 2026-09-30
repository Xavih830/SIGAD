"""SIGAD FastAPI Application Entry Point."""

from fastapi import FastAPI

from app.api.v1.api import api_router
from app.core.handlers import register_handlers

app = FastAPI(
    title="SIGAD API",
    description="Sistema Integral de Gestión de Asegurados — Backend",
    version="0.1.0",
)

# Register global exception handlers (SQLAlchemyError → no PII in logs)
register_handlers(app)

# Mount API v1 routes
app.include_router(api_router)


@app.get("/health", tags=["Infra"])
async def health() -> dict:
    """Simple health check for Docker / load-balancer probes."""
    return {"status": "ok"}
