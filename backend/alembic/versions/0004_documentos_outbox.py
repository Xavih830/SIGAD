"""Documentos outbox y resultados de extraccion OCR.

Revision ID: 0004
Revises: 0003
Create Date: 2026-09-30
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

# revision identifiers, used by Alembic.
revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "documentos",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("poliza_id", UUID(as_uuid=True), sa.ForeignKey("polizas.id", ondelete="SET NULL"), nullable=True),
        sa.Column("nombre_archivo", sa.String(255), nullable=False),
        sa.Column("ruta_archivo", sa.String(512), nullable=False),
        sa.Column("tipo_mime", sa.String(100), nullable=False),
        sa.Column("tamano_bytes", sa.BigInteger(), nullable=False),
        sa.Column("hash_sha256", sa.String(64), nullable=False),
        sa.Column("estado_extraccion", sa.String(30), nullable=False, server_default=sa.text("'pendiente'")),
        sa.Column("intentos", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("error_motivo", sa.Text(), nullable=True),
        sa.Column("lease_token", UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("tamano_bytes <= 15728640", name="chk_documentos_max_size_15mb"),
        sa.CheckConstraint(
            "estado_extraccion IN ('pendiente', 'procesando', 'completado', 'requiere_revision_manual', 'error', 'error_permanente')",
            name="chk_documentos_estado_extraccion",
        ),
    )
    op.create_index("ix_documentos_poliza_id", "documentos", ["poliza_id"])
    op.create_index("ix_documentos_hash_sha256", "documentos", ["hash_sha256"])
    op.create_index("ix_documentos_estado_extraccion", "documentos", ["estado_extraccion"])
    op.create_index("ix_documentos_lease_token", "documentos", ["lease_token"])

    op.create_table(
        "resultados_extraccion",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "documento_id",
            UUID(as_uuid=True),
            sa.ForeignKey("documentos.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("texto_completo", sa.Text(), nullable=False),
        sa.Column("metodo", sa.String(20), nullable=False),
        sa.Column("confianza", sa.Numeric(5, 2), nullable=False),
        sa.Column("campos_extraidos", JSONB, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint(
            "metodo IN ('pdfplumber', 'tesseract_200dpi')",
            name="chk_resultados_extraccion_metodo",
        ),
    )
    op.create_index("ix_resultados_extraccion_documento_id", "resultados_extraccion", ["documento_id"])


def downgrade() -> None:
    op.drop_table("resultados_extraccion")
    op.drop_table("documentos")
