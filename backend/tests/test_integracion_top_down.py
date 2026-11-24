# Top-Down: módulo superior real, módulo inferior (poliza_evaluator) simulado
from datetime import date
from unittest.mock import Mock


# Módulo superior (resumen de PolizaService.crear_poliza)
def crear_poliza(fecha_inicio, fecha_fin, evaluador):
    estado = evaluador.validar_y_calcular_estado_inicial(fecha_inicio, fecha_fin, date.today())
    evaluador.validar_limite_vigencia_maxima(fecha_inicio, fecha_fin)
    return {"estado": estado}


# Stub del módulo inferior
evaluador_simulado = Mock()
evaluador_simulado.validar_y_calcular_estado_inicial.return_value = "activa"

# Ejecución
resultado = crear_poliza(date(2026, 1, 1), date(2027, 1, 1), evaluador_simulado)

# Verificación de la integración
evaluador_simulado.validar_y_calcular_estado_inicial.assert_called_once()
evaluador_simulado.validar_limite_vigencia_maxima.assert_called_once()
print("OK - estado devuelto:", resultado["estado"])