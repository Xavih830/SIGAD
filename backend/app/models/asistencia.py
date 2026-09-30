"""Asistencia model — emergency roadside assistance catalog in PostgreSQL."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Asistencia(Base):
    """Tabla `asistencias` — catálogo de servicios y números de emergencia."""

    __tablename__ = "asistencias"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    titulo: Mapped[str] = mapped_column(String(255), nullable=False)
    descripcion: Mapped[str] = mapped_column(Text, nullable=False)
    telefono_emergencia: Mapped[str] = mapped_column(String(50), nullable=False)
    icono: Mapped[str] = mapped_column(String(100), nullable=False)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
