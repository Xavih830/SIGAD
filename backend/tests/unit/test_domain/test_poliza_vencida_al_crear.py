"""CFG Path 3 Test: 1-2-3(Sí)-5(No)-7(Sí)-8-10 -> EstadoPoliza.VENCIDA.

Obligatory Test #9 / #33 (Section 4.5 & Section 21 of poryecto.md).
Verifies that when fecha_fin < hoy, the initial policy state is 'vencida'.
"""

from datetime import date, timedelta
from app.domain.poliza_evaluator import EstadoPoliza, validar_y_calcular_estado_inicial


def test_poliza_fechas_pasadas_retorna_vencida():
    """Path 3: Past policy with fecha_fin < hoy evaluates to EstadoPoliza.VENCIDA."""
    hoy = date(2026, 9, 30)
    fecha_inicio = date(2024, 1, 1)
    fecha_fin = date(2025, 1, 1)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.VENCIDA
    assert estado.value == "vencida"


def test_poliza_vencida_ayer():
    """Boundary value: fecha_fin = hoy - 1 día evaluates to EstadoPoliza.VENCIDA."""
    hoy = date(2026, 9, 30)
    fecha_inicio = hoy - timedelta(days=365)
    fecha_fin = hoy - timedelta(days=1)

    estado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert estado == EstadoPoliza.VENCIDA
    assert estado.value == "vencida"
