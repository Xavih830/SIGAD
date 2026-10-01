"""Pydantic v2 schemas for the auth endpoint."""

from pydantic import BaseModel, Field, field_validator

from app.schemas.base import StrictBaseSchema


class LoginRequest(StrictBaseSchema):
    """Login payload — accepts email (contains @) or cédula (numeric)."""
    identificador: str = Field(..., min_length=1, max_length=100, description="Email or cédula")
    password: str = Field(..., min_length=1)

    @field_validator("identificador", "password")
    @classmethod
    def reject_null_bytes(cls, v: str) -> str:
        if "\x00" in v:
            raise ValueError("Caracteres nulos no permitidos.")
        return v


class TokenResponse(BaseModel):
    """JWT token pair returned on successful login."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: dict
