from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict

T = TypeVar("T")


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


class PaginatedResponse(BaseModel, Generic[T]):
    """Esquema de respuesta paginado estándar."""

    items: list[T]
    total: int
    skip: int
    limit: int

    model_config = ConfigDict(from_attributes=True)

