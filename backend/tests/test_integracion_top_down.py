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
print("=== PRUEBA DE INTEGRACIÓN TOP-DOWN ===")
print("Módulo superior: crear_poliza (real)")
print("Módulo inferior: poliza_evaluator (simulado con stub)\n")

resultado = crear_poliza(date(2026, 1, 1), date(2027, 1, 1), evaluador_simulado)
print("1. Se ejecutó crear_poliza con fechas 2026-01-01 a 2027-01-01")

# Verificación de la integración
evaluador_simulado.validar_y_calcular_estado_inicial.assert_called_once()
print("2. OK: el servicio llamó al evaluador para calcular el estado inicial")

evaluador_simulado.validar_limite_vigencia_maxima.assert_called_once()
print("3. OK: el servicio llamó al evaluador para validar la vigencia máxima")

assert resultado["estado"] == "activa"
print(f"4. OK: el servicio usó el estado devuelto por el stub -> '{resultado['estado']}'")

print("\nRESULTADO: la integración entre el servicio y el evaluador funciona correctamente")