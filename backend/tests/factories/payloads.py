"""Factories for generating valid API request payloads, eliminating test data scattering."""

from datetime import date, timedelta
from decimal import Decimal
import uuid

from tests.factories.helpers import generar_cedula_valida, generar_placa_valida


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
    default.update(overrides)
    return default


def vehiculo_payload(cliente_id: uuid.UUID | str, **overrides) -> dict:
    """Generate a valid VehiculoCreate request dictionary."""
    default = {
        "placa": generar_placa_valida(),
        "marca": "Toyota",
        "modelo": "Corolla Cross XEI",
        "anio": 2023,
        "cliente_id": str(cliente_id),
    }
    default.update(overrides)
    return default


def cliente_payload(**overrides) -> dict:
    """Generate a valid ClienteCreate request dictionary."""
    uid = uuid.uuid4().hex[:6]
    default = {
        "identificacion": generar_cedula_valida(),
        "nombres": f"Cliente Prueba {uid.upper()}",
        "email": f"cliente_{uid}@test.sigad.ec",
        "telefono": "0991234567",
    }
    default.update(overrides)
    return default


def login_payload(identificador: str, password: str = "TestPass1234!*") -> dict:
    """Generate a LoginRequest dictionary."""
    return {
        "identificador": identificador,
        "password": password,
    }
