"""Poliza model — insurance policy contracts and relationships."""

from datetime import date, datetime, timezone
from decimal import Decimal
import uuid

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, Numeric, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.domain.poliza_evaluator import EstadoPoliza


class Poliza(Base):
    """Tabla `polizas` — pólizas de seguro automotor."""

    __tablename__ = "polizas"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    numero_poliza: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, index=True)
    cliente_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("clientes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    vehiculo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("vehiculos.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    inspeccion_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("inspecciones.id", ondelete="SET NULL"),
        nullable=True,
    )
    fecha_inicio: Mapped[date] = mapped_column(Date, nullable=False)
    fecha_fin: Mapped[date] = mapped_column(Date, nullable=False)
    estado: Mapped[EstadoPoliza] = mapped_column(
        Enum(EstadoPoliza, name="estado_poliza_enum", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        index=True,
    )
    valor_asegurado: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    prima_mensual: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    
    # Snapshot contractual inmutable (SC-2026-001 & Sec 3.2):
    kilometraje_emision: Mapped[int] = mapped_column(Integer, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=text("now()"),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        server_default=text("now()"),
        nullable=False,
    )

    # Relationships
    cliente = relationship("Cliente", back_populates="polizas")
    vehiculo = relationship("Vehiculo", back_populates="polizas")
    inspeccion = relationship("Inspeccion")
    deducibles = relationship(
        "Deducible",
        back_populates="poliza",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    coberturas = relationship(
        "Cobertura",
        back_populates="poliza",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    pagos = relationship(
        "Pago",
        back_populates="poliza",
        cascade="all, delete-orphan",
        order_by="Pago.numero_cuota",
        lazy="selectin",
    )
