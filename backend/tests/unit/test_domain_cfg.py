"""Consolidated Control Flow Graph (CFG) Test Suite for app.domain.poliza_evaluator.

Verification Gate 1: 100% branch and statement coverage for app.domain.
Formally verifies all 4 basis paths:
  - Path 1: 1-2-3(No)-4 -> FechaInvalidaException
  - Path 2: 1-2-3(Sí)-5(Sí)-6-10 -> EstadoPoliza.PENDIENTE
  - Path 3: 1-2-3(Sí)-5(No)-7(Sí)-8-10 -> EstadoPoliza.VENCIDA
  - Path 4: 1-2-3(Sí)-5(No)-7(No)-9-10 -> EstadoPoliza.ACTIVA
"""

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
        """Basis Path 1: 1-2-3(No)-4 -> FechaInvalidaException (Node 4 Sink)."""
        hoy = date(2026, 9, 30)
        # 1a. Fin menor a inicio
        with pytest.raises(FechaInvalidaException):
            validar_y_calcular_estado_inicial(date(2026, 5, 10), date(2026, 5, 9), hoy)

        # 1b. Fin igual a inicio
        with pytest.raises(FechaInvalidaException):
            validar_y_calcular_estado_inicial(date(2026, 5, 10), date(2026, 5, 10), hoy)

    def test_path_2_poliza_pendiente(self):
        """Basis Path 2: 1-2-3(Sí)-5(Sí)-6-10 -> EstadoPoliza.PENDIENTE."""
        hoy = date(2026, 9, 30)
        inicio = date(2026, 10, 1)
        fin = date(2027, 10, 1)
        assert validar_y_calcular_estado_inicial(inicio, fin, hoy) == EstadoPoliza.PENDIENTE

    def test_path_3_poliza_vencida(self):
        """Basis Path 3: 1-2-3(Sí)-5(No)-7(Sí)-8-10 -> EstadoPoliza.VENCIDA."""
        hoy = date(2026, 9, 30)
        inicio = date(2025, 1, 1)
        fin = date(2026, 1, 1)
        assert validar_y_calcular_estado_inicial(inicio, fin, hoy) == EstadoPoliza.VENCIDA

    def test_path_4_poliza_activa(self):
        """Basis Path 4: 1-2-3(Sí)-5(No)-7(No)-9-10 -> EstadoPoliza.ACTIVA."""
        hoy = date(2026, 9, 30)
        inicio = date(2026, 1, 1)
        fin = date(2027, 1, 1)
        assert validar_y_calcular_estado_inicial(inicio, fin, hoy) == EstadoPoliza.ACTIVA

    def test_limite_vigencia_5_anios_cobertura(self):
        """Verify boundary checks for 5-year maximum duration."""
        inicio = date(2026, 3, 15)
        limite = calcular_fecha_limite_vigencia(inicio)
        assert limite == date(2031, 3, 15)

        # Valido dentro de los 5 años
        validar_limite_vigencia_maxima(inicio, limite)

        # Invalido al superar los 5 años
        with pytest.raises(VigenciaExcedidaException):
            validar_limite_vigencia_maxima(inicio, limite + timedelta(days=1))

    def test_limite_vigencia_bisiesto_cobertura(self):
        """Verify leap year handling in calculation."""
        bisiesto = date(2024, 2, 29)
        limite = calcular_fecha_limite_vigencia(bisiesto)
        assert limite == date(2029, 2, 28)
