"""Canonical test fixtures and mock entity builders for the backend test suite.

Centralizes mock actors, credentials, and domain entity mocks to eliminate
boilerplate and manual attribute assignment in unit tests.
"""

from unittest.mock import MagicMock
import uuid

from app.core.constants import (
    OCR_DEFAULT_KILOMETRAJE,
    OCR_DEFAULT_PRIMA_MENSUAL,
    OCR_DEFAULT_VALOR_ASEGURADO,
)
from app.core.security import hash_password
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.cliente import Cliente
from app.models.poliza import Poliza
from app.models.usuario import RolEnum, Usuario

# ── Canonical Constants ───────────────────────────────────────────────────────
ADMIN_EMAIL = "admin@sigad.ec"
ADMIN_PASSWORD = "Admin#SIGAD24"
ADMIN_NAME = "Administrador del Sistema"

AGENTE_EMAIL = "agente@sigad.ec"
AGENTE_PASSWORD = "Agente#SIGAD24"
AGENTE_NAME = "Agente de Seguros"

CLIENTE_CEDULA = "0926687856"
CLIENTE_EMAIL = "m.leon@hotmail.com"
CLIENTE_NAME = "María José León Andrade"
CLIENTE_PASSWORD = "PasswordSeguro2026*"

DEFAULT_OTP = "123456"

DEFAULT_CAMPOS_EXTRAIDOS = {
    "numero_poliza": "POL-2026-999",
    "placa": "ABC-1234",
    "marca": "Toyota",
    "modelo": "Corolla Cross",
    "valor_asegurado": float(OCR_DEFAULT_VALOR_ASEGURADO),
    "prima_mensual": float(OCR_DEFAULT_PRIMA_MENSUAL),
    "kilometraje": OCR_DEFAULT_KILOMETRAJE,
}

# ── Catálogos Globales ────────────────────────────────────────────────────────
TALLER_NOMBRE = "Taller Central Guayaquil"
TALLER_CIUDAD = "Guayaquil"
TALLER_DIRECCION = "Av. Juan Tanca Marengo Km 4.5"
TALLER_TELEFONO = "042987654"

ASISTENCIA_TITULO = "Grúa 24/7 Nacional"
ASISTENCIA_DESCRIPCION = "Remolque y asistencia mecánica ligera en todo el país"
ASISTENCIA_TELEFONO = "1800-ASISTE"
ASISTENCIA_ICONO = "tow-truck"


# ── Validation Messages & Error Strings ───────────────────────────────────────
MSG_PASSWORD_MIN_LENGTH = "al menos 12 caracteres"
MSG_PASSWORD_REQUIRES_UPPER = "letra mayúscula"
MSG_PASSWORD_REQUIRES_LOWER = "letra minúscula"
MSG_PASSWORD_REQUIRES_DIGIT = "al menos un número"
MSG_PASSWORD_REQUIRES_SPECIAL = "carácter especial"
MSG_PASSWORD_MISMATCH = "confirmación de la contraseña no coincide"
MSG_EMAIL_DUPLICADO = "El correo electrónico ya se encuentra registrado"

VALID_PASSWORDS = [
    CLIENTE_PASSWORD,
    ADMIN_PASSWORD,
    "Compl3x!P@ssword2026",
    "Abcdef123456!@",
]

INVALID_PASSWORDS = {
    "too_short": "Short1!Aa",
    "missing_upper": "passwordseguro2026*",
    "missing_lower": "PASSWORDSEGURO2026*",
    "missing_digit": "PasswordSeguroSinNumero*",
    "missing_special": "PasswordSeguro2026",
}


def create_mock_user(
    *,
    id: uuid.UUID | None = None,
    email: str | None = None,
    password: str | None = None,
    nombre: str | None = None,
    rol: RolEnum = RolEnum.ADMIN,
    activo: bool = True,
) -> MagicMock:
    """Create a fully initialized MagicMock mimicking a Usuario entity."""
    user = MagicMock(spec=Usuario)
    user.id = id or uuid.uuid4()
    if rol == RolEnum.ADMIN:
        user.email = email or ADMIN_EMAIL
        pwd = password or ADMIN_PASSWORD
        user.nombre = nombre or ADMIN_NAME
    elif rol == RolEnum.AGENTE:
        user.email = email or AGENTE_EMAIL
        pwd = password or AGENTE_PASSWORD
        user.nombre = nombre or AGENTE_NAME
    else:
        user.email = email or CLIENTE_EMAIL
        pwd = password or CLIENTE_PASSWORD
        user.nombre = nombre or CLIENTE_NAME

    user.password_hash = hash_password(pwd)
    user.rol = rol
    user.activo = activo
    return user


def create_mock_admin_user(**kwargs) -> MagicMock:
    """Convenience shortcut for an ADMIN mock user."""
    return create_mock_user(rol=RolEnum.ADMIN, **kwargs)


def create_mock_cliente_user(**kwargs) -> MagicMock:
    """Convenience shortcut for a CLIENTE mock user."""
    return create_mock_user(rol=RolEnum.CLIENTE, **kwargs)


def create_mock_agente_user(**kwargs) -> MagicMock:
    """Convenience shortcut for an AGENTE mock user."""
    return create_mock_user(rol=RolEnum.AGENTE, **kwargs)


def create_mock_cliente(
    *,
    id: uuid.UUID | None = None,
    identificacion: str = CLIENTE_CEDULA,
    nombres: str = CLIENTE_NAME,
    email: str = CLIENTE_EMAIL,
    telefono: str = "0991234567",
    usuario_id: uuid.UUID | None = None,
) -> MagicMock:
    """Create a fully initialized MagicMock mimicking a Cliente entity."""
    cliente = MagicMock(spec=Cliente)
    cliente.id = id or uuid.uuid4()
    cliente.identificacion = identificacion
    cliente.nombres = nombres
    cliente.email = email
    cliente.telefono = telefono
    cliente.usuario_id = usuario_id
    return cliente


def create_mock_poliza(
    *,
    id: uuid.UUID | None = None,
    numero_poliza: str = "POL-2026-001",
    estado: EstadoPoliza = EstadoPoliza.ACTIVA,
    cliente_id: uuid.UUID | None = None,
    vehiculo_id: uuid.UUID | None = None,
) -> MagicMock:
    """Create a fully initialized MagicMock mimicking a Poliza entity."""
    poliza = MagicMock(spec=Poliza)
    poliza.id = id or uuid.uuid4()
    poliza.numero_poliza = numero_poliza
    poliza.estado = estado
    poliza.cliente_id = cliente_id or uuid.uuid4()
    poliza.vehiculo_id = vehiculo_id or uuid.uuid4()
    return poliza
