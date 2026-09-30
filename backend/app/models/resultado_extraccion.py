"""ResultadoExtraccion model — structured data extracted via OCR/digital pipeline."""

from datetime import datetime, timezone
from decimal import Decimal
import uuid

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Numeric, String, Text, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ResultadoExtraccion(Base):
    """Tabla `resultados_extraccion` — campos de vehículos y pólizas extraídos de documentos."""

    __tablename__ = "resultados_extraccion"
    __table_args__ = (
        CheckConstraint(
            "metodo IN ('pdfplumber', 'tesseract_200dpi')",
            name="chk_resultados_extraccion_metodo",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    documento_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("documentos.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    texto_completo: Mapped[str] = mapped_column(Text, nullable=False)
    metodo: Mapped[str] = mapped_column(String(20), nullable=False)
    confianza: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    campos_extraidos: Mapped[dict] = mapped_column(JSONB, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=text("now()"),
        nullable=False,
    )

    # Relación
    documento = relationship("Documento", back_populates="resultado")
