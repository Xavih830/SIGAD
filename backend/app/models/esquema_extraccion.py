"""EsquemaExtraccion — append-only, campos como JSONB con CHECK de cardinalidad."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class EsquemaExtraccion(Base):
    """Tabla `esquemas_extraccion`.

    Append-only: cada versión publicada crea una fila nueva.
    No se hace UPDATE ni DELETE sobre versiones publicadas.
    Versión activa: WHERE codigo = X AND es_activo = true.

    Estructura de cada elemento en `campos`:
    {
        "nombre": "placa",           # str, max 100 chars
        "regex": "\\b([A-Z]{3}...)\\b", # str, max 500 chars
        "tipo": "texto",             # "texto"|"numero"|"decimal"|"fecha"
        "grupo_captura": 1,          # int >= 1
        "formato_fecha": null,       # str|null, solo si tipo="fecha"
        "es_obligatorio": true,      # bool
        "orden": 0                   # int >= 0
    }
    """

    __tablename__ = "esquemas_extraccion"
    __table_args__ = (
        CheckConstraint("version > 0", name="chk_esquema_version_positiva"),
        CheckConstraint(
            "jsonb_array_length(campos) BETWEEN 1 AND 50",
            name="chk_esquema_max_campos",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    codigo: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    nombre: Mapped[str] = mapped_column(String(100), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text, nullable=True)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    es_activo: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    campos: Mapped[list] = mapped_column(JSONB, nullable=False)
    creado_por: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=text("now()"),
        nullable=False,
    )
