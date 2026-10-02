"""Factories for generating valid API request payloads, eliminating test data scattering."""

from datetime import date, datetime, timedelta
from decimal import Decimal
import uuid

from tests.factories.fixtures import (
    ASISTENCIA_DESCRIPCION,
    ASISTENCIA_ICONO,
    ASISTENCIA_TELEFONO,
    ASISTENCIA_TITULO,
    CLIENTE_CEDULA,
    CLIENTE_PASSWORD,
    DEFAULT_CAMPOS_EXTRAIDOS,
    DEFAULT_OTP,
    TALLER_CIUDAD,
    TALLER_DIRECCION,
    TALLER_NOMBRE,
    TALLER_TELEFONO,
)
from tests.factories.helpers import generar_cedula_valida, generar_placa_valida


def _normalize_value(v):
    if isinstance(v, (date, datetime)):
        return v.isoformat()
    if isinstance(v, uuid.UUID):
        return str(v)
    if isinstance(v, Decimal):
        return float(v)
    return v


def _apply_overrides(target: dict, overrides: dict) -> dict:
    for k, v in overrides.items():
        target[k] = _normalize_value(v)
    return target


def poliza_payload(
    cliente_id: uuid.UUID | str,
    vehiculo_id: uuid.UUID | str,
    **overrides,
) -> dict:
    """Generate a valid PolizaCreate request dictionary with sensible defaults.
    
    Tests only need to pass the fields they are explicitly testing:
        payload = poliza_payload(c_id, v_id, valor_asegurado=50000.0)
    """
    f_ini = date.today()
    f_fin = f_ini + timedelta(days=365)
    uid = uuid.uuid4().hex[:6].upper()

    default = {
        "numero_poliza": f"POL-TEST-{uid}",
        "cliente_id": str(cliente_id),
        "vehiculo_id": str(vehiculo_id),
        "fecha_inicio": f_ini.isoformat(),
        "fecha_fin": f_fin.isoformat(),
        "valor_asegurado": 19500.00,
        "prima_mensual": 48.00,
        "kilometraje_emision": 18200,
        "coberturas": [
            {"nombre": "Responsabilidad Civil", "monto": 50000.00},
            {"nombre": "Daño Emergente", "monto": 15000.00},
        ],
    }
    return _apply_overrides(default, overrides)


def vehiculo_payload(cliente_id: uuid.UUID | str, **overrides) -> dict:
    """Generate a valid VehiculoCreate request dictionary."""
    default = {
        "placa": generar_placa_valida(),
        "marca": "Toyota",
        "modelo": "Corolla Cross XEI",
        "anio": 2023,
        "cliente_id": str(cliente_id),
    }
    return _apply_overrides(default, overrides)


def cliente_payload(**overrides) -> dict:
    """Generate a valid ClienteCreate request dictionary."""
    uid = uuid.uuid4().hex[:6]
    default = {
        "identificacion": generar_cedula_valida(),
        "nombres": f"Cliente Prueba {uid.upper()}",
        "email": f"cliente_{uid}@test.sigad.ec",
        "telefono": "0991234567",
    }
    return _apply_overrides(default, overrides)


def login_payload(identificador: str, password: str = CLIENTE_PASSWORD) -> dict:
    """Generate a LoginRequest dictionary using canonical password by default."""
    return {
        "identificador": identificador,
        "password": password,
    }


def pago_payload(
    metodo_pago: str = "transferencia",
    comprobante_ref: str = "DEP-PICHINCHA-5544",
    fecha_pago: date | str | None = None,
    **overrides,
) -> dict:
    """Generate a valid RegistrarPagoRequest dictionary."""
    default = {
        "metodo_pago": metodo_pago,
        "comprobante_ref": comprobante_ref,
    }
    if fecha_pago is not None:
        default["fecha_pago"] = fecha_pago.isoformat() if isinstance(fecha_pago, (date, datetime)) else str(fecha_pago)
    return _apply_overrides(default, overrides)

def vinculacion_payload(
    cedula: str = CLIENTE_CEDULA,
    codigo_otp: str = DEFAULT_OTP,
    password: str = CLIENTE_PASSWORD,
    password_confirmacion: str | None = None,
    **overrides,
) -> dict:
    """Generate a valid VinculacionRequest dictionary."""
    default = {
        "cedula": cedula,
        "codigo_otp": codigo_otp,
        "password": password,
        "password_confirmacion": password_confirmacion if password_confirmacion is not None else password,
    }
    return _apply_overrides(default, overrides)


def revision_documento_payload(
    campos_extraidos: dict | None = None,
    estado_extraccion: str = "completado",
    **overrides,
) -> dict:
    """Generate a valid RevisionDocumentoRequest dictionary."""
    default = {
        "campos_extraidos": campos_extraidos if campos_extraidos is not None else DEFAULT_CAMPOS_EXTRAIDOS.copy(),
        "estado_extraccion": estado_extraccion,
    }
    return _apply_overrides(default, overrides)


def taller_payload(**overrides) -> dict:
    """Generate a valid TallerCreate request dictionary with canonical defaults."""
    default = {
        "nombre": TALLER_NOMBRE,
        "direccion": TALLER_DIRECCION,
        "telefono": TALLER_TELEFONO,
        "ciudad": TALLER_CIUDAD,
        "activo": True,
    }
    return _apply_overrides(default, overrides)


def asistencia_payload(**overrides) -> dict:
    """Generate a valid AsistenciaCreate request dictionary with canonical defaults."""
    default = {
        "titulo": ASISTENCIA_TITULO,
        "descripcion": ASISTENCIA_DESCRIPCION,
        "telefono_emergencia": ASISTENCIA_TELEFONO,
        "icono": ASISTENCIA_ICONO,
        "activo": True,
    }
    return _apply_overrides(default, overrides)


