"""Pruebas de análisis de flujo de datos y pares def-use para validar_y_calcular_estado_inicial."""

import ast
from datetime import date, timedelta
import inspect

import pytest

from app.core.exceptions import FechaInvalidaException
from app.domain.poliza_evaluator import (
    EstadoPoliza,
    calcular_fecha_limite_vigencia,
    validar_limite_vigencia_maxima,
    validar_y_calcular_estado_inicial,
)


def test_ast_data_flow_static_no_anomalies():
    """Static AST inspection verifying def-use structure and single-assignment per path."""
    source = inspect.getsource(validar_y_calcular_estado_inicial)
    tree = ast.parse(source)

    func_def = tree.body[0]
    assert isinstance(func_def, ast.FunctionDef)

    param_names = [arg.arg for arg in func_def.args.args]
    assert param_names == ["fecha_inicio", "fecha_fin", "hoy"]

    assignments = []
    returns = []
    raises = []

    for node in ast.walk(func_def):
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name):
                    assignments.append(target.id)
        elif isinstance(node, ast.Return):
            if isinstance(node.value, ast.Name):
                returns.append(node.value.id)
        elif isinstance(node, ast.Raise):
            raises.append(node)

    assert assignments.count("estado") == 3, "Debe haber exactamente 3 definiciones condicionales de estado"
    assert returns == ["estado"], "El retorno debe consumir la variable 'estado'"
    assert len(raises) == 1, "Debe existir exactamente 1 sumidero de excepción (Nodo 4)"


def test_dynamic_all_uses_coverage():
    """Exercise all def-use pairs through dynamic execution."""
    hoy = date(2026, 9, 30)

    with pytest.raises(FechaInvalidaException):
        validar_y_calcular_estado_inicial(date(2026, 5, 10), date(2026, 5, 1), hoy)

    estado_p = validar_y_calcular_estado_inicial(hoy + timedelta(days=5), hoy + timedelta(days=370), hoy)
    assert estado_p == EstadoPoliza.PENDIENTE

    estado_v = validar_y_calcular_estado_inicial(hoy - timedelta(days=400), hoy - timedelta(days=10), hoy)
    assert estado_v == EstadoPoliza.VENCIDA

    estado_a = validar_y_calcular_estado_inicial(hoy - timedelta(days=30), hoy + timedelta(days=335), hoy)
    assert estado_a == EstadoPoliza.ACTIVA


def test_bva_vigencia_maxima_5_anios():
    """Verifica el análisis de valores frontera para el límite de 5 años de vigencia."""
    inicio = date(2026, 1, 1)

    fin_exacto = calcular_fecha_limite_vigencia(inicio)
    assert fin_exacto == date(2031, 1, 1)
    validar_limite_vigencia_maxima(inicio, fin_exacto)

    fin_excedido = fin_exacto + timedelta(days=1)
    with pytest.raises(Exception):
        validar_limite_vigencia_maxima(inicio, fin_excedido)


def test_bva_bisiesto_vigencia():
    """Verifica el manejo de año bisiesto (29 de febrero) en el cálculo de vigencia."""
    inicio_bisiesto = date(2028, 2, 29)
    fin_5_anios = calcular_fecha_limite_vigencia(inicio_bisiesto)
    assert fin_5_anios == date(2033, 2, 28)
    validar_limite_vigencia_maxima(inicio_bisiesto, fin_5_anios)
