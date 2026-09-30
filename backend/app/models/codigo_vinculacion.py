"""CodigoVinculacion model — secure HMAC-based OTP for mobile client onboarding."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class CodigoVinculacion(Base):
    """Tabla `codigos_vinculacion` — almacenamiento seguro del OTP con HMAC-SHA256."""

    __tablename__ = "codigos_vinculacion"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    cliente_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("clientes.id", ondelete="CASCADE"),
        nullable=False,
    )
    codigo_hmac: Mapped[str] = mapped_column(String(64), nullable=False)
    expira_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumido: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    intentos_fallidos: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    cliente = relationship("Cliente", backref="codigos_vinculacion")
