"""Pydantic v2 schemas package."""

from app.schemas.auth import (
    LoginRequest,
    TokenResponse,
)
from app.schemas.base import StrictBaseSchema
from app.schemas.cliente import (
    ClienteCreate,
    ClienteResponse,
    VinculacionRequest,
    validar_cedula_ecuatoriana,
    validar_complejidad_password,
)
from app.schemas.deducible import (
    DeducibleCreate,
    DeducibleResponse,
)
from app.schemas.documento import (
    DocumentoListItemResponse,
    DocumentoResponse,
    DocumentoRevisionRequest,
    DocumentoRevisionResponse,
    ResultadoExtraccionResponse,
)
from app.schemas.pago import (
    PagoResponse,
    RegistrarPagoRequest,
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
    "StrictBaseSchema",
    "LoginRequest",
    "TokenResponse",
    "ClienteCreate",
    "ClienteResponse",
    "VinculacionRequest",
    "validar_cedula_ecuatoriana",
    "validar_complejidad_password",
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
    "DocumentoRevisionRequest",
    "DocumentoResponse",
    "DocumentoRevisionResponse",
    "DocumentoListItemResponse",
    "ResultadoExtraccionResponse",
    "PagoResponse",
    "RegistrarPagoRequest",
]
