"""Pydantic v2 schemas for the auth endpoint."""

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    """Login payload — accepts email (contains @) or cédula (numeric)."""
    identificador: str = Field(..., min_length=1, description="Email or cédula")
    password: str = Field(..., min_length=1)


class TokenResponse(BaseModel):
    """JWT token pair returned on successful login."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: dict
