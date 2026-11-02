"""Modelo de datos SQLAlchemy para pagos y cronograma de cuotas."""

import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Integer, Numeric, String, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Pago(Base):
    """Tabla `pagos` — cuotas y cronograma de pagos de pólizas."""

    __tablename__ = "pagos"
    __table_args__ = (
        CheckConstraint("estado IN ('pendiente', 'pagado', 'atrasado')", name="chk_estado_pago"),
        UniqueConstraint("poliza_id", "numero_cuota", name="uq_poliza_cuota"),
    )

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
    numero_cuota: Mapped[int] = mapped_column(Integer, nullable=False)
    monto_usd: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    fecha_vencimiento: Mapped[date] = mapped_column(Date, nullable=False)
    fecha_pago: Mapped[date | None] = mapped_column(Date, nullable=True)
    estado: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="pendiente",
        server_default=text("'pendiente'"),
        index=True,
    )
    metodo_pago: Mapped[str | None] = mapped_column(String(50), nullable=True)
    comprobante_ref: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        server_default=text("now()"),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        server_default=text("now()"),
        nullable=False,
    )

    poliza = relationship("Poliza", back_populates="pagos")
