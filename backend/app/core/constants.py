"""Constantes canónicas del sistema SIGAD.

Centraliza todos los límites de infraestructura, cuotas, timeouts y umbrales.
"""

from decimal import Decimal

# ── Almacenamiento y Documentos ──────────────────────────────────────────────
MAX_DOCUMENT_SIZE_BYTES: int = 15 * 1024 * 1024  # 15 Megabytes exactos
MAX_PDF_PAGES_PERMITTED: int = 10
PERMITTED_MIME_TYPES: tuple[str, ...] = (
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/tiff",
)

# ── Pipeline de Extracción y OCR ─────────────────────────────────────────────
OCR_PROCESS_TIMEOUT_SECONDS: int = 120
TESSERACT_STANDARD_DPI: int = 200
GATE1_TEXT_LENGTH_THRESHOLD: int = 50
OCR_HIGH_CONFIDENCE_THRESHOLD: Decimal = Decimal("80.0")
OCR_DEFAULT_VALOR_ASEGURADO: Decimal = Decimal("15000.00")
OCR_DEFAULT_PRIMA_MENSUAL: Decimal = Decimal("35.00")
OCR_DEFAULT_KILOMETRAJE: int = 5000


# ── Confiabilidad, Watchdog y Outbox ─────────────────────────────────────────
MAX_OCR_FAILED_ATTEMPTS: int = 3
WATCHDOG_STALE_MINUTES: int = 5
WATCHDOG_INTERVAL_SECONDS: int = 60
OUTBOX_POLL_INTERVAL_SECONDS: float = 1.0

# ── Seguridad, Autenticación y Rate Limiting ──────────────────────────────────
ARGON2_MEMORY_COST: int = 19456  # 19 MiB según especificación técnica
ARGON2_TIME_COST: int = 2
ARGON2_PARALLELISM: int = 1

OTP_LENGTH: int = 6
MAX_FAILED_OTP_ATTEMPTS: int = 3
OTP_EXPIRATION_MINUTES: int = 15
MIN_PASSWORD_LENGTH: int = 12

RATE_LIMIT_LOGIN_MAX_REQUESTS: int = 5
RATE_LIMIT_LOGIN_WINDOW_SECONDS: int = 900  # 15 minutos
RATE_LIMIT_VINCULACION_MAX_REQUESTS: int = 3
RATE_LIMIT_VINCULACION_WINDOW_SECONDS: int = 60  # 1 minuto
RATE_LIMIT_LOCKOUT_MAX_FAILS: int = 10
RATE_LIMIT_LOCKOUT_WINDOW_SECONDS: int = 3600  # 1 hora
RATE_LIMIT_LOCKOUT_DURATION_SECONDS: int = 1800  # 30 minutos
RATE_LIMIT_VINCULACION_IDENTITY_WINDOW_SECONDS: int = 3600  # 1 hora
RATE_LIMIT_TARPIT_BURST_THRESHOLD: int = 2
RATE_LIMIT_TARPIT_BURST_WINDOW_SECONDS: float = 10.0
RATE_LIMIT_TARPIT_BASE_DELAY_SECONDS: float = 0.5
RATE_LIMIT_TARPIT_MAX_DELAY_SECONDS: float = 5.0
RATE_LIMIT_LRU_MAXSIZE: int = 10000

# ── Dominio de Pólizas y Vehículos ───────────────────────────────────────────
DIAS_ALERTA_POR_VENCER: int = 30
MAX_VIGENCIA_ANIOS: int = 5
DEFAULT_DEDUCIBLE_PORCENTAJE: Decimal = Decimal("10.0")
DEFAULT_DEDUCIBLE_MINIMO_USD: Decimal = Decimal("200.00")

# ── Cronograma de Pagos y Cuotas (HU-20) ──────────────────────────────────────
MIN_CUOTAS_POLIZA: int = 1
MAX_CUOTAS_POLIZA_ANUAL: int = 12
DIAS_PERIODO_CUOTA_MENSUAL: int = 30

# ── Esquemas de Extracción Configurables ──────────────────────────────────────
MAX_CAMPOS_POR_ESQUEMA: int = 50
MAX_REGEX_LENGTH: int = 500
MAX_NOMBRE_CAMPO_LENGTH: int = 100
MAX_DESCRIPCION_ESQUEMA_LENGTH: int = 500

