"""Core configuration loaded strictly from environment / .env via Pydantic Settings.

Zero Fallbacks Principle (12-Factor App & OWASP):
- Secrets and external connections have NO default values in code.
- Sensitive fields are masked via SecretStr to prevent leakages in logs and telemetry.
- Configuration is loaded strictly from a single canonical point (.env in current working directory).
"""

from functools import lru_cache
from typing import Literal

from pydantic import SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings sourced strictly from environment or local .env file."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # 1. Entorno de Ejecución
    ENVIRONMENT: Literal["development", "staging", "production", "testing"] = "development"

    # 2. Base de Datos PostgreSQL (FAIL-FAST: Sin defaults)
    DATABASE_URL: str
    DATABASE_SYNC_URL: str
    SQL_ECHO: bool = False

    # 3. Seguridad JWT (FAIL-FAST: Sin defaults, enmascarado)
    JWT_SECRET_KEY: SecretStr
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # 4. OTP HMAC con Rotación Trimestral (FAIL-FAST: Sin defaults, enmascarado)
    OTP_SECRET_KEY_ACTUAL: SecretStr
    OTP_SECRET_KEY_ANTERIOR: SecretStr
    OTP_EXPIRATION_MINUTES: int = 15

    # 5. Canal SMTP Corporativo (FAIL-FAST: Sin defaults)
    SMTP_HOST: str
    SMTP_PORT: int
    SMTP_FROM_EMAIL: str
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_USE_TLS: bool = False

    # 6. Servidor Uvicorn
    UVICORN_WORKERS: int = 2
    UVICORN_HOST: str = "0.0.0.0"
    UVICORN_PORT: int = 8000

    # 7. Almacenamiento
    UPLOAD_DIR: str = "uploads"

    # 8. Rate Limiting
    RATE_LIMITING_ENABLED: bool = True

    @model_validator(mode="after")
    def validate_production_security_guards(self) -> "Settings":
        """Strict production guards: prevents running in production with weak secrets."""
        if self.ENVIRONMENT == "production":
            jwt_val = self.JWT_SECRET_KEY.get_secret_value()
            if len(jwt_val) < 32:
                raise ValueError("JWT_SECRET_KEY must be at least 32 characters in production.")
            if any(weak in jwt_val.lower() for weak in ["change-me", "dev", "test", "secret"]):
                raise ValueError("Insecure JWT_SECRET_KEY placeholder detected in production environment.")
            if self.SQL_ECHO:
                raise ValueError("SQL_ECHO must be False in production to avoid leaking sensitive query data.")
        return self


@lru_cache
def get_settings() -> Settings:
    """Cached settings factory supporting dependency injection and test overrides."""
    return Settings()


# Singleton export for application modules
settings = get_settings()
