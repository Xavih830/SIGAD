"""Pydantic v2 schemas package."""

from app.schemas.auth import (
    LoginRequest,
    TokenResponse,
)
from app.schemas.deducible import (
    DeducibleCreate,
    DeducibleResponse,
)
from app.schemas.poliza import (
    CoberturaCreate,
    CoberturaResponse,
    PolizaCreate,
    PolizaResponse,
    PolizaUpdateEstado,
)
from app.schemas.vehiculo import (
    VehiculoCreate,
    VehiculoResponse,
    validar_placa_ecuador,
)

__all__ = [
    "LoginRequest",
    "TokenResponse",
    "VehiculoCreate",
    "VehiculoResponse",
    "validar_placa_ecuador",
    "DeducibleCreate",
    "DeducibleResponse",
    "CoberturaCreate",
    "CoberturaResponse",
    "PolizaCreate",
    "PolizaResponse",
    "PolizaUpdateEstado",
]
