"""Vehiculo model — vehicle records associated with clients."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Vehiculo(Base):
    """Tabla `vehiculos` — registro automotor sin campo de kilometraje mutable.
    
    El kilometraje se almacena en `inspecciones` y se captura como snapshot inmutable
    en `polizas.kilometraje_emision`.
    """

    __tablename__ = "vehiculos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    placa: Mapped[str] = mapped_column(String(10), unique=True, nullable=False, index=True)
    marca: Mapped[str] = mapped_column(String(100), nullable=False)
    modelo: Mapped[str] = mapped_column(String(100), nullable=False)
    anio: Mapped[int] = mapped_column(Integer, nullable=False)
    cliente_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("clientes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
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
    cliente = relationship("Cliente", back_populates="vehiculos")
    polizas = relationship("Poliza", back_populates="vehiculo", cascade="all, delete-orphan")
    inspecciones = relationship("Inspeccion", back_populates="vehiculo", cascade="all, delete-orphan")
