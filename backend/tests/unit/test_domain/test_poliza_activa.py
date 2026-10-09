"""Pruebas unitarias para pólizas vigentes en curso (estado activa)."""

from datetime import date, timedelta
from app.domain.poliza_evaluator import EstadoPoliza, validar_y_calcular_estado_inicial


def test_poliza_vigente_retorna_activa():
    """Verifica que una póliza vigente (fecha_inicio < hoy < fecha_fin) evalúa a EstadoPoliza.ACTIVA."""
    hoy = date(2026, 9, 30)
    fecha_inicio = date(2026, 1, 1)
    fecha_fin = date(2027, 1, 1)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.ACTIVA
    assert estado.value == "activa"


def test_poliza_limite_inferior_inicio_hoy():
    """Verifica el caso de frontera donde fecha_inicio es igual a hoy."""
    hoy = date(2026, 9, 30)
    fecha_inicio = hoy
    fecha_fin = hoy + timedelta(days=365)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.ACTIVA
    assert estado.value == "activa"


def test_poliza_limite_fin_hoy():
    """Verifica el caso de frontera donde fecha_fin es igual a hoy."""
    hoy = date(2026, 9, 30)
    fecha_inicio = hoy - timedelta(days=30)
    fecha_fin = hoy

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.ACTIVA
    assert estado.value == "activa"
