"""Esquemas de poliza dinamicos y campos adicionales gobernados (append-only).

Revision ID: 0007_esquemas_poliza
Revises: 0006_esquemas_extraccion
Create Date: 2026-10-09 15:40:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "0007_esquemas_poliza"
down_revision: Union[str, None] = "0006_esquemas_extraccion"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "esquemas_poliza",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("codigo", sa.String(80), nullable=False),
        sa.Column("nombre", sa.String(100), nullable=False),
        sa.Column("descripcion", sa.Text(), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column(
            "es_activo",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column("campos", JSONB, nullable=False),
        sa.Column(
            "creado_por",
            UUID(as_uuid=True),
            sa.ForeignKey("usuarios.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint("version > 0", name="chk_esquema_poliza_version_positiva"),
        sa.CheckConstraint(
            "jsonb_array_length(campos) BETWEEN 1 AND 50",
            name="chk_esquema_poliza_max_campos",
        ),
    )
    op.create_index(
        op.f("ix_esquemas_poliza_codigo"),
        "esquemas_poliza",
        ["codigo"],
        unique=False,
    )

    op.add_column(
        "polizas",
        sa.Column(
            "esquema_id",
            UUID(as_uuid=True),
            sa.ForeignKey("esquemas_poliza.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.add_column(
        "polizas",
        sa.Column("campos_adicionales", JSONB, nullable=True),
    )
    op.create_index(
        op.f("ix_polizas_esquema_id"),
        "polizas",
        ["esquema_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_polizas_esquema_id"), table_name="polizas")
    op.drop_column("polizas", "campos_adicionales")
    op.drop_column("polizas", "esquema_id")
    op.drop_index(op.f("ix_esquemas_poliza_codigo"), table_name="esquemas_poliza")
    op.drop_table("esquemas_poliza")
