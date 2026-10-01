"""Test data factories for the SIGAD test suite."""

from tests.factories.helpers import (
    generar_cedula_valida,
    generar_fechas_poliza,
    generar_placa_valida,
)
from tests.factories.models import (
    create_cliente,
    create_poliza,
    create_user,
    create_vehiculo,
)
from tests.factories.payloads import (
    cliente_payload,
    login_payload,
    pago_payload,
    poliza_payload,
    vehiculo_payload,
)
from tests.factories.scenarios import (
    ScenarioBundle,
    create_base_scenario,
)

__all__ = [
    "generar_cedula_valida",
    "generar_placa_valida",
    "generar_fechas_poliza",
    "create_user",
    "create_cliente",
    "create_vehiculo",
    "create_poliza",
    "poliza_payload",
    "pago_payload",
    "vehiculo_payload",
    "cliente_payload",
    "login_payload",
    "ScenarioBundle",
    "create_base_scenario",
]
