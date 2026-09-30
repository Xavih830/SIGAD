"""CFG Path 1 Test: 1-2-3(No)-4 -> Exception Sink (Node 4).

Obligatory Test #7 / #35 (Section 4.5 & Section 21 of poryecto.md).
Verifies that when fecha_fin <= fecha_inicio, the evaluator raises FechaInvalidaException
and NEVER returns 'error'.
"""

from datetime import date
import pytest

from app.core.exceptions import FechaInvalidaException
from app.domain.poliza_evaluator import validar_y_calcular_estado_inicial


def test_fecha_fin_menor_que_inicio_lanza_excepcion():
    """Path 1a: fecha_fin < fecha_inicio -> raises FechaInvalidaException."""
    fecha_inicio = date(2026, 6, 1)
    fecha_fin = date(2026, 5, 1)
    hoy = date(2026, 5, 15)

    with pytest.raises(FechaInvalidaException) as exc_info:
        validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert "posterior a la fecha de inicio" in str(exc_info.value)


def test_fecha_fin_igual_a_inicio_lanza_excepcion():
    """Path 1b: fecha_fin == fecha_inicio -> raises FechaInvalidaException (boundary case)."""
    fecha_inicio = date(2026, 6, 1)
    fecha_fin = date(2026, 6, 1)
    hoy = date(2026, 5, 15)

    with pytest.raises(FechaInvalidaException) as exc_info:
        validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert "posterior a la fecha de inicio" in str(exc_info.value)


def test_no_retorna_error_string():
    """Verify that domain never returns an 'error' string state, but terminates at exception sink."""
    fecha_inicio = date(2026, 10, 1)
    fecha_fin = date(2026, 9, 1)
    hoy = date(2026, 9, 15)

    try:
        resultado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)
        pytest.fail(f"Se esperaba FechaInvalidaException pero retornó: {resultado}")
    except FechaInvalidaException:
        pass
