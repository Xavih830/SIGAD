"""Pruebas unitarias para validación de fechas inválidas en pólizas."""

from datetime import date
import pytest

from app.core.exceptions import FechaInvalidaException
from app.domain.poliza_evaluator import validar_y_calcular_estado_inicial


def test_fecha_fin_menor_que_inicio_lanza_excepcion():
    """Verifica que fecha_fin < fecha_inicio lanza FechaInvalidaException."""
    fecha_inicio = date(2026, 6, 1)
    fecha_fin = date(2026, 5, 1)
    hoy = date(2026, 5, 15)

    with pytest.raises(FechaInvalidaException) as exc_info:
        validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert "posterior a la fecha de inicio" in str(exc_info.value)


def test_fecha_fin_igual_a_inicio_lanza_excepcion():
    """Verifica que fecha_fin == fecha_inicio lanza FechaInvalidaException en caso de frontera."""
    fecha_inicio = date(2026, 6, 1)
    fecha_fin = date(2026, 6, 1)
    hoy = date(2026, 5, 15)

    with pytest.raises(FechaInvalidaException) as exc_info:
        validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)

    assert "posterior a la fecha de inicio" in str(exc_info.value)


def test_no_retorna_error_string():
    """Verifica que el evaluador no retorna strings de error sino que lanza la excepción correspondiente."""
    fecha_inicio = date(2026, 10, 1)
    fecha_fin = date(2026, 9, 1)
    hoy = date(2026, 9, 15)

    try:
        resultado = validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, hoy)
        pytest.fail(f"Se esperaba FechaInvalidaException pero retornó: {resultado}")
    except FechaInvalidaException:
        pass
