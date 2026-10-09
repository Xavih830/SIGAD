"""Evaluador de dominio para el ciclo de vida y cálculo de estado inicial de pólizas."""

from datetime import date
import enum

from app.core.constants import MAX_VIGENCIA_ANIOS
from app.core.exceptions import FechaInvalidaException, VigenciaExcedidaException


class EstadoPoliza(str, enum.Enum):
    """Ciclo de vida formal de cinco estados para una póliza."""

    PENDIENTE = "pendiente"
    ACTIVA = "activa"
    POR_VENCER = "por_vencer"
    VENCIDA = "vencida"
    CANCELADA = "cancelada"


def validar_y_calcular_estado_inicial(
    fecha_inicio: date,
    fecha_fin: date,
    hoy: date,
) -> EstadoPoliza:
    """Evalúa y calcula el estado inicial de una póliza respecto a la fecha de referencia.

    Raises:
        FechaInvalidaException: Si fecha_fin <= fecha_inicio.
    """
    if fecha_fin <= fecha_inicio:
        raise FechaInvalidaException(
            "La fecha de fin debe ser estrictamente posterior a la fecha de inicio."
        )

    if hoy < fecha_inicio:
        estado = EstadoPoliza.PENDIENTE
    elif fecha_fin < hoy:
        estado = EstadoPoliza.VENCIDA
    else:
        estado = EstadoPoliza.ACTIVA

    return estado


def calcular_fecha_limite_vigencia(fecha_inicio: date) -> date:
    """Calcula la fecha límite contractual según la vigencia máxima permitida."""
    try:
        return fecha_inicio.replace(year=fecha_inicio.year + MAX_VIGENCIA_ANIOS)
    except ValueError:
        return fecha_inicio.replace(year=fecha_inicio.year + MAX_VIGENCIA_ANIOS, day=28)


def validar_limite_vigencia_maxima(fecha_inicio: date, fecha_fin: date) -> None:
    """Valida que la duración de la póliza no supere el límite máximo contractual.

    Raises:
        VigenciaExcedidaException: Si fecha_fin supera el límite máximo de vigencia.
    """
    limite = calcular_fecha_limite_vigencia(fecha_inicio)
    if fecha_fin > limite:
        raise VigenciaExcedidaException(
            f"La vigencia de la póliza excede el límite máximo contractual de 5 años (máximo hasta {limite.isoformat()})."
        )
