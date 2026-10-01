"""Core configuration loaded from environment variables via Pydantic Settings."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings sourced from environment / .env file."""

    # PostgreSQL
    DATABASE_URL: str = "postgresql+asyncpg://sigad:sigad_dev_2024@localhost:5432/sigad_db"
    DATABASE_SYNC_URL: str = "postgresql://sigad:sigad_dev_2024@localhost:5432/sigad_db"
    SQL_ECHO: bool = False

    # JWT
    JWT_SECRET_KEY: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Argon2id
    ARGON2_MEMORY_COST: int = 19456
    ARGON2_TIME_COST: int = 2
    ARGON2_PARALLELISM: int = 1

    # OTP HMAC
    OTP_SECRET_KEY_ACTUAL: str = "sigad_otp_secret_key_actual_2026_q1"
    OTP_SECRET_KEY_ANTERIOR: str = "sigad_otp_secret_key_anterior_2025_q4"
    OTP_EXPIRATION_MINUTES: int = 15

    # Rate Limiting
    RATE_LIMITING_ENABLED: bool = True

    model_config = {"env_file": ".env", "extra": "ignore"}



settings = Settings()
