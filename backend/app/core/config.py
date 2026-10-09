"""Core configuration loaded strictly from environment / .env via Pydantic Settings.

Zero Fallbacks Principle (12-Factor App & OWASP):
- Secrets and external connections have NO default values in code.
- Sensitive fields are masked via SecretStr to prevent leakages in logs and telemetry.
- Configuration is loaded strictly from a single canonical point (.env in current working directory).
"""

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_CANONICAL_ROOT_ENV = Path(__file__).resolve().parents[3] / ".env"
_ENV_FILE_SOURCE = _CANONICAL_ROOT_ENV if _CANONICAL_ROOT_ENV.exists() else None


class Settings(BaseSettings):
    """Configuración de la aplicación cargada desde variables de entorno o archivo .env."""

    model_config = SettingsConfigDict(
        env_file=_ENV_FILE_SOURCE,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    ENVIRONMENT: Literal["development", "staging", "production", "testing"] = "development"

    DATABASE_URL: str
    DATABASE_SYNC_URL: str
    SQL_ECHO: bool = False

    JWT_SECRET_KEY: SecretStr
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    OTP_SECRET_KEY_ACTUAL: SecretStr
    OTP_SECRET_KEY_ANTERIOR: SecretStr
    OTP_EXPIRATION_MINUTES: int = 15

    SMTP_HOST: str
    SMTP_PORT: int
    SMTP_FROM_EMAIL: str
    SMTP_USER: str = ""
    SMTP_PASSWORD: SecretStr = SecretStr("")
    SMTP_USE_TLS: bool = False

    UVICORN_WORKERS: int = 2
    UVICORN_HOST: str = "0.0.0.0"
    UVICORN_PORT: int = 8000

    UPLOAD_DIR: str = "uploads"

    @field_validator("UPLOAD_DIR")
    @classmethod
    def validate_upload_dir_security(cls, v: str) -> str:
        raw = v.strip()
        if Path(raw).is_absolute() or raw.startswith(("/", "\\")):
            raise ValueError(f"UPLOAD_DIR no puede ser una ruta absoluta: {v}")
        clean = raw.strip("/\\")
        if not clean or ".." in clean or clean in (".", "app", "tests", "core", "models", "api", "workers"):
            raise ValueError(f"Directorio UPLOAD_DIR inseguro o reservado: {v}")
        return clean

    RATE_LIMITING_ENABLED: bool = True

    CORS_ORIGINS: list[str] = [
        "http://localhost",
        "http://localhost:80",
        "http://localhost:8000",
        "http://localhost:8085",
        "http://127.0.0.1",
        "http://127.0.0.1:8000",
        "http://127.0.0.1:8085",
    ]

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


settings = get_settings()
