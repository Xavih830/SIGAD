"""Documento model — physical uploaded files for OCR and inspection."""

from datetime import datetime, timezone
import enum
import uuid

from sqlalchemy import BigInteger, CheckConstraint, DateTime, ForeignKey, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class EstadoExtraccionEnum(str, enum.Enum):
    PENDIENTE = "pendiente"
    PROCESANDO = "procesando"
    COMPLETADO = "completado"
    REQUIERE_REVISION_MANUAL = "requiere_revision_manual"
    ERROR = "error"
    ERROR_PERMANENTE = "error_permanente"


class Documento(Base):
    """Tabla `documentos` — gestión de archivos subidos y cola de extracción OCR."""

    __tablename__ = "documentos"
    __table_args__ = (
        CheckConstraint("tamano_bytes <= 15728640", name="chk_documentos_max_size_15mb"),
        CheckConstraint(
            "estado_extraccion IN ('pendiente', 'procesando', 'completado', 'requiere_revision_manual', 'error', 'error_permanente')",
            name="chk_documentos_estado_extraccion",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    poliza_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("polizas.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    nombre_archivo: Mapped[str] = mapped_column(String(255), nullable=False)
    ruta_archivo: Mapped[str] = mapped_column(String(512), nullable=False)
    tipo_mime: Mapped[str] = mapped_column(String(100), nullable=False)
    tamano_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    hash_sha256: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    estado_extraccion: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=EstadoExtraccionEnum.PENDIENTE.value,
        server_default=text("'pendiente'"),
        index=True,
    )
    intentos: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default=text("0"),
    )
    error_motivo: Mapped[str | None] = mapped_column(Text, nullable=True)
    lease_token: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
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

    # Relaciones
    poliza = relationship("Poliza")
    resultado = relationship(
        "ResultadoExtraccion",
        back_populates="documento",
        uselist=False,
        cascade="all, delete-orphan",
        lazy="selectin",
    )
