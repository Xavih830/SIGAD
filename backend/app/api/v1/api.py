"""API v1 router aggregator."""

from fastapi import APIRouter

from app.api.v1.endpoints import (
    asistencias,
    auth,
    clientes,
    documentos,
    esquemas,
    esquemas_poliza,
    pagos,
    polizas,
    talleres,
    vehiculos,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(clientes.router)
api_router.include_router(polizas.router)
api_router.include_router(pagos.router)
api_router.include_router(vehiculos.router)
api_router.include_router(talleres.router)
api_router.include_router(asistencias.router)
api_router.include_router(documentos.router)
api_router.include_router(esquemas.router)
api_router.include_router(esquemas_poliza.router)


