"""Global exception handlers.

Key invariant: SQLAlchemyError handler logs ONLY the exception type, SQLSTATE,
and request path — **never** bound parameters or the full exc object — to
prevent PII from leaking into logs.
"""

import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from app.core.exceptions import (
    EmailDuplicadoException,
    FechaInvalidaException,
    VigenciaExcedidaException,
)

logger = logging.getLogger("sigad.handlers")


def register_handlers(app: FastAPI) -> None:
    """Attach global exception handlers to the FastAPI application."""

    @app.exception_handler(EmailDuplicadoException)
    async def email_duplicado_handler(request: Request, exc: EmailDuplicadoException) -> JSONResponse:
        return JSONResponse(
            status_code=409,
            content={"detail": exc.message},
        )

    @app.exception_handler(FechaInvalidaException)
    async def fecha_invalida_handler(request: Request, exc: FechaInvalidaException) -> JSONResponse:

        return JSONResponse(
            status_code=422,
            content={"detail": exc.message},
        )

    @app.exception_handler(VigenciaExcedidaException)
    async def vigencia_excedida_handler(request: Request, exc: VigenciaExcedidaException) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={"detail": exc.message},
        )

    @app.exception_handler(SQLAlchemyError)
    async def sqlalchemy_error_handler(request: Request, exc: SQLAlchemyError) -> JSONResponse:
        sqlstate = getattr(getattr(exc, "orig", None), "pgcode", "N/A")

        logger.error(
            "db_error type=%s sqlstate=%s path=%s",
            type(exc).__name__,
            sqlstate,
            request.url.path,
        )
        return JSONResponse(
            status_code=500,
            content={"detail": "Error interno del servidor."},
        )
