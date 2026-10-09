"""Pruebas de grafo de flujo de control (CFG) para app.domain.poliza_evaluator."""

from datetime import date, timedelta
import pytest

from app.core.exceptions import FechaInvalidaException, VigenciaExcedidaException
from app.domain.poliza_evaluator import (
    EstadoPoliza,
    calcular_fecha_limite_vigencia,
    validar_limite_vigencia_maxima,
    validar_y_calcular_estado_inicial,
)


class TestDominioCFG:
    """Rigorous structural testing of the domain evaluator."""

    def test_path_1_fecha_fin_invalida(self):
        """Verifica que fechas de fin iguales o anteriores a inicio lanzan FechaInvalidaException."""
        hoy = date(2026, 9, 30)
        with pytest.raises(FechaInvalidaException):
            validar_y_calcular_estado_inicial(date(2026, 5, 10), date(2026, 5, 9), hoy)

        with pytest.raises(FechaInvalidaException):
            validar_y_calcular_estado_inicial(date(2026, 5, 10), date(2026, 5, 10), hoy)

    def test_path_2_poliza_pendiente(self):
        """Verifica que una póliza que inicia en el futuro queda en estado PENDIENTE."""
        hoy = date(2026, 9, 30)
        inicio = date(2026, 10, 1)
        fin = date(2027, 10, 1)
        assert validar_y_calcular_estado_inicial(inicio, fin, hoy) == EstadoPoliza.PENDIENTE

    def test_path_3_poliza_vencida(self):
        """Verifica que una póliza cuya vigencia ya concluyó queda en estado VENCIDA."""
        hoy = date(2026, 9, 30)
        inicio = date(2025, 1, 1)
        fin = date(2026, 1, 1)
        assert validar_y_calcular_estado_inicial(inicio, fin, hoy) == EstadoPoliza.VENCIDA

    def test_path_4_poliza_activa(self):
        """Verifica que una póliza dentro de su vigencia queda en estado ACTIVA."""
        hoy = date(2026, 9, 30)
        inicio = date(2026, 1, 1)
        fin = date(2027, 1, 1)
        assert validar_y_calcular_estado_inicial(inicio, fin, hoy) == EstadoPoliza.ACTIVA

    def test_limite_vigencia_5_anios_cobertura(self):
        """Verify boundary checks for 5-year maximum duration."""
        inicio = date(2026, 3, 15)
        limite = calcular_fecha_limite_vigencia(inicio)
        assert limite == date(2031, 3, 15)

        validar_limite_vigencia_maxima(inicio, limite)

        with pytest.raises(VigenciaExcedidaException):
            validar_limite_vigencia_maxima(inicio, limite + timedelta(days=1))

    def test_limite_vigencia_bisiesto_cobertura(self):
        """Verify leap year handling in calculation."""
        bisiesto = date(2024, 2, 29)
        limite = calcular_fecha_limite_vigencia(bisiesto)
        assert limite == date(2029, 2, 28)
