"""Pruebas unitarias para pólizas con inicio futuro (estado pendiente)."""

from datetime import date, timedelta
from app.domain.poliza_evaluator import EstadoPoliza, validar_y_calcular_estado_inicial


def test_poliza_inicio_futuro_retorna_pendiente():
    """Verifica que cuando hoy < fecha_inicio, el estado inicial de la póliza es pendiente."""
    hoy = date(2026, 9, 30)
    fecha_inicio = date(2026, 10, 15)
    fecha_fin = date(2027, 10, 15)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.PENDIENTE
    assert estado.value == "pendiente"


def test_poliza_limite_inferior_futuro_inmediato():
    """Verifica el caso de frontera donde fecha_inicio es el día siguiente a hoy."""
    hoy = date(2026, 9, 30)
    fecha_inicio = hoy + timedelta(days=1)
    fecha_fin = fecha_inicio + timedelta(days=365)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.PENDIENTE
    assert estado.value == "pendiente"
