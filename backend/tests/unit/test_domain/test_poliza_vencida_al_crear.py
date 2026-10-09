"""Pruebas unitarias para pólizas con fechas pasadas (estado vencida)."""

from datetime import date, timedelta
from app.domain.poliza_evaluator import EstadoPoliza, validar_y_calcular_estado_inicial


def test_poliza_fechas_pasadas_retorna_vencida():
    """Verifica que cuando fecha_fin < hoy, el estado inicial de la póliza es vencida."""
    hoy = date(2026, 9, 30)
    fecha_inicio = date(2024, 1, 1)
    fecha_fin = date(2025, 1, 1)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.VENCIDA
    assert estado.value == "vencida"


def test_poliza_vencida_ayer():
    """Verifica el caso de frontera donde fecha_fin es el día anterior a hoy."""
    hoy = date(2026, 9, 30)
    fecha_inicio = hoy - timedelta(days=365)
    fecha_fin = hoy - timedelta(days=1)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.VENCIDA
    assert estado.value == "vencida"
