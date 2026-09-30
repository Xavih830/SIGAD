"""CFG Path 2 Test: 1-2-3(Sí)-5(Sí)-6-10 -> EstadoPoliza.PENDIENTE.

Obligatory Test #8 / #32 (Section 4.5 & Section 21 of poryecto.md).
Verifies that when hoy < fecha_inicio, the initial policy state is 'pendiente'.
"""

from datetime import date, timedelta
from app.domain.poliza_evaluator import EstadoPoliza, validar_y_calcular_estado_inicial


def test_poliza_inicio_futuro_retorna_pendiente():
    """Path 2: Future policy with hoy < fecha_inicio evaluates to EstadoPoliza.PENDIENTE."""
    hoy = date(2026, 9, 30)
    fecha_inicio = date(2026, 10, 15)
    fecha_fin = date(2027, 10, 15)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.PENDIENTE
    assert estado.value == "pendiente"


def test_poliza_limite_inferior_futuro_inmediato():
    """Boundary value: fecha_inicio = hoy + 1 día evaluates to EstadoPoliza.PENDIENTE."""
    hoy = date(2026, 9, 30)
    fecha_inicio = hoy + timedelta(days=1)
    fecha_fin = fecha_inicio + timedelta(days=365)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.PENDIENTE
    assert estado.value == "pendiente"
