"""Domain and business logic exceptions for SIGAD."""


class SIGADException(Exception):
    """Base exception for all domain errors."""

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class FechaInvalidaException(SIGADException):
    """Raised when policy dates are chronologically incoherent (fecha_fin <= fecha_inicio).
    
    Represents Node 4 (Exception Sink) in the formal Control Flow Graph (CFG) of
    validar_y_calcular_estado_inicial.
    """

    def __init__(self, message: str = "La fecha de fin debe ser estrictamente posterior a la fecha de inicio.") -> None:
        super().__init__(message)


class VigenciaExcedidaException(SIGADException):
    """Raised when policy duration exceeds the maximum contractual period (5 years)."""

    def __init__(self, message: str = "La vigencia de la póliza no puede superar los 5 años contractuales.") -> None:
        super().__init__(message)


class EmailDuplicadoException(SIGADException):
    """Raised when client email already exists in usuarios table during vinculacion (HTTP 409)."""

    def __init__(self, message: str = "El correo electrónico ya se encuentra registrado") -> None:
        super().__init__(message)

