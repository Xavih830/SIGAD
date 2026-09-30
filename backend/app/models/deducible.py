"""Deducible model — SC-2026-001 differentiated deductibles per incident type."""

import enum
import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import DateTime, Enum, ForeignKey, Numeric, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class TipoSiniestroEnum(str, enum.Enum):
    """Categorías formales de siniestro para deducibles diferenciados (SC-2026-001)."""
    GENERAL = "general"
    ROBO = "robo"
    CHOQUE = "choque"
    PERDIDA_TOTAL = "perdida_total"


class Deducible(Base):
    """Tabla `deducibles` — deducibles por tipo de siniestro según SC-2026-001."""

    __tablename__ = "deducibles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    poliza_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("polizas.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tipo_siniestro: Mapped[TipoSiniestroEnum] = mapped_column(
        Enum(TipoSiniestroEnum, name="tipo_siniestro_enum", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    porcentaje_valor: Mapped[Decimal] = mapped_column(
        Numeric(5, 2),
        nullable=False,
    )
    monto_minimo_usd: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=text("now()"),
        nullable=False,
    )

    # Relationships
    poliza = relationship("Poliza", back_populates="deducibles")
