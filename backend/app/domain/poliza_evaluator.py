"""Domain evaluator for policy lifecycle and state evaluation.

Implements the formal CFG (10 nodes, 11 edges, V(G)=4) and def-use integrity
specified in SOFG1008 and Section 4 of poryecto.md.
"""

from datetime import date
import enum

from app.core.exceptions import FechaInvalidaException, VigenciaExcedidaException


class EstadoPoliza(str, enum.Enum):
    """Formal 5-state policy lifecycle.

    States 'error' and 'borrador' are strictly prohibited in the domain model.
    'por_vencer' is only assigned by the temporal background scheduler.
    """

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
    """Evaluate the initial state of a policy according to Section 4 of the specification.

    Control Flow Graph (CFG) Structure:
      - 10 Discrete Nodes, 11 Directed Edges
      - Cyclomatic Complexity V(G) = E - N + 2P = 13 - 11 + 2 = 4 (Standard Virtual Sink)
      - Dual Sinks: Node 4 (Exception Sink) and Node 10 (Return Sink)

    Nodes:
      1: Entry
      2: Validate format and coherence
      3: Predicate: is fecha_fin <= fecha_inicio?
      4: Exception Sink: raise FechaInvalidaException
      5: Predicate: is hoy < fecha_inicio?
      6: Assign estado = EstadoPoliza.PENDIENTE
      7: Predicate: is fecha_fin < hoy?
      8: Assign estado = EstadoPoliza.VENCIDA
      9: Assign estado = EstadoPoliza.ACTIVA
      10: Return Sink: return estado

    Def-Use Associations:
      - fecha_inicio: def(param) -> use(2/3), def(param) -> use(5)
      - fecha_fin:    def(param) -> use(2/3), def(param) -> use(7)
      - hoy:          def(param) -> use(5),   def(param) -> use(7)
      - estado:       def(6) -> use(10), def(8) -> use(10), def(9) -> use(10)

    Absence of Anomalies:
      - No UR (Undefined-Referenced): estado is defined on every path reaching Node 10.
      - No DU (Defined-Unused): every assignment to estado reaches Node 10.
      - No DD (Defined-Defined): exactly one definition of estado per execution path.
    """
    # Node 1 (Entry), Node 2 (Coherence check), Node 3 (Predicate)
    if fecha_fin <= fecha_inicio:
        # Node 4 (Exception Sink)
        raise FechaInvalidaException(
            "La fecha de fin debe ser estrictamente posterior a la fecha de inicio."
        )

    # Node 5 (Predicate)
    if hoy < fecha_inicio:
        # Node 6 (Assignment)
        estado = EstadoPoliza.PENDIENTE
    # Node 7 (Predicate)
    elif fecha_fin < hoy:
        # Node 8 (Assignment)
        estado = EstadoPoliza.VENCIDA
    else:
        # Node 9 (Assignment)
        estado = EstadoPoliza.ACTIVA

    # Node 10 (Return Sink)
    return estado


def calcular_fecha_limite_vigencia(fecha_inicio: date) -> date:
    """Calculate the maximum 5-year contractual limit handling leap years."""
    try:
        return fecha_inicio.replace(year=fecha_inicio.year + 5)
    except ValueError:
        # Leap year leap-day (e.g. Feb 29 -> Feb 28 on non-leap year + 5)
        return fecha_inicio.replace(year=fecha_inicio.year + 5, day=28)


def validar_limite_vigencia_maxima(fecha_inicio: date, fecha_fin: date) -> None:
    """Validate that policy duration does not exceed the maximum allowed period (5 years).

    Boundary Value Analysis (Section 11.3):
      - Upper boundary: fecha_fin == fecha_inicio + 5 years -> Accepted
      - Upper boundary + 1 day: fecha_fin > fecha_inicio + 5 years -> Raises VigenciaExcedidaException
    """
    limite = calcular_fecha_limite_vigencia(fecha_inicio)
    if fecha_fin > limite:
        raise VigenciaExcedidaException(
            f"La vigencia de la póliza excede el límite máximo contractual de 5 años (máximo hasta {limite.isoformat()})."
        )
