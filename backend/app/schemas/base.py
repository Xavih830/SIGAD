"""Esquema base estricto para todos los DTOs de entrada en FastAPI."""

from pydantic import BaseModel, ConfigDict


class StrictBaseSchema(BaseModel):
    """Esquema base hermético:
    - extra='forbid': Rechaza con HTTP 422 si se envían campos no declarados.
    - strict=True: Prohíbe la coerción implícita de tipos (ej. '123' a int).
    - str_strip_whitespace=True: Elimina espacios iniciales y finales en cadenas.
    """

    model_config = ConfigDict(
        extra="forbid",
        strict=True,
        str_strip_whitespace=True,
        from_attributes=True,
    )
