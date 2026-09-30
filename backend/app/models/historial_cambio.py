"""HistorialCambio model — audit log of entity modifications populated by PostgreSQL triggers."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import BigInteger, DateTime, ForeignKey, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class HistorialCambio(Base):
    """Tabla `historial_cambios` — auditoría a nivel de base de datos para entidades clave."""

    __tablename__ = "historial_cambios"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    entidad: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    entidad_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    campo: Mapped[str] = mapped_column(String(100), nullable=False)
    valor_anterior: Mapped[str | None] = mapped_column(Text, nullable=True)
    valor_nuevo: Mapped[str | None] = mapped_column(Text, nullable=True)
    usuario_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        nullable=True,
    )
    fecha: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=text("now()"),
        nullable=False,
    )
