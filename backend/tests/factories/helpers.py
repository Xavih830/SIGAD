"""Helpers for generating valid, compliant Ecuadorian test data."""

import random
import string
from datetime import date, timedelta


def generar_cedula_valida() -> str:
    """Generate a mathematically valid Ecuadorian national ID (Cédula) matching Módulo 10.
    
    Rules:
    - 2-digit province code (01 - 24)
    - 3rd digit between 0 and 5 (natural person)
    - 6 sequential random digits
    - 1 check digit calculated with alternating coefficients [2, 1, 2, 1, 2, 1, 2, 1, 2]
    """
    provincia = f"{random.randint(1, 24):02d}"
    tercer_digito = str(random.randint(0, 5))
    seis_digitos = "".join([str(random.randint(0, 9)) for _ in range(6)])
    base_9 = provincia + tercer_digito + seis_digitos

    coeficientes = [2, 1, 2, 1, 2, 1, 2, 1, 2]
    suma = 0
    for i in range(9):
        prod = int(base_9[i]) * coeficientes[i]
        suma += (prod - 9) if prod >= 10 else prod

    digito_verificador = (10 - (suma % 10)) % 10
    return base_9 + str(digito_verificador)


def generar_placa_valida(prefijo_provincia: str | None = None) -> str:
    """Generate an official ANT-compliant license plate (e.g. PBA-1234)."""
    provincias = ["P", "G", "A", "T", "L", "M", "E", "C", "H", "O"]
    p1 = prefijo_provincia if prefijo_provincia else random.choice(provincias)
    p2 = random.choice(string.ascii_uppercase)
    p3 = random.choice(string.ascii_uppercase)
    num = f"{random.randint(1000, 9999)}"
    return f"{p1}{p2}{p3}-{num}"


def generar_fechas_poliza(dias: int = 365, inicio: date | None = None) -> tuple[str, str]:
    """Generate ISO format start and end dates for a policy."""
    fecha_inicio = inicio or date.today()
    fecha_fin = fecha_inicio + timedelta(days=dias)
    return fecha_inicio.isoformat(), fecha_fin.isoformat()
