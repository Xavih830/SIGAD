"""Taller model — authorized workshops catalog in PostgreSQL."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Taller(Base):
    """Tabla `talleres` — red de talleres mecánicos autorizados."""

    __tablename__ = "talleres"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    nombre: Mapped[str] = mapped_column(String(255), nullable=False)
    direccion: Mapped[str] = mapped_column(String(255), nullable=False)
    telefono: Mapped[str] = mapped_column(String(50), nullable=False)
    ciudad: Mapped[str] = mapped_column(String(100), nullable=False)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
