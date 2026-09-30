"""CFG Path 4 Test: 1-2-3(Sí)-5(No)-7(No)-9-10 -> EstadoPoliza.ACTIVA.

Obligatory Test #10 / #34 (Section 4.5 & Section 21 of poryecto.md).
Verifies that when policy is currently in force (fecha_inicio <= hoy <= fecha_fin),
the initial state is 'activa'.
"""

from datetime import date, timedelta
from app.domain.poliza_evaluator import EstadoPoliza, validar_y_calcular_estado_inicial


def test_poliza_vigente_retorna_activa():
    """Path 4: In-force policy (fecha_inicio < hoy < fecha_fin) evaluates to EstadoPoliza.ACTIVA."""
    hoy = date(2026, 9, 30)
    fecha_inicio = date(2026, 1, 1)
    fecha_fin = date(2027, 1, 1)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.ACTIVA
    assert estado.value == "activa"


def test_poliza_limite_inferior_inicio_hoy():
    """Boundary value: fecha_inicio = hoy, fecha_fin > hoy evaluates to EstadoPoliza.ACTIVA."""
    hoy = date(2026, 9, 30)
    fecha_inicio = hoy
    fecha_fin = hoy + timedelta(days=365)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.ACTIVA
    assert estado.value == "activa"


def test_poliza_limite_fin_hoy():
    """Boundary value: fecha_fin = hoy, fecha_inicio < hoy evaluates to EstadoPoliza.ACTIVA."""
    hoy = date(2026, 9, 30)
    fecha_inicio = hoy - timedelta(days=30)
    fecha_fin = hoy

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.ACTIVA
    assert estado.value == "activa"
