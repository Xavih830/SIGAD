"""Crea tabla pagos y genera cronograma de cuotas inicial para polizas vigentes.

Revision ID: 0005_tabla_pagos
Revises: 0004
Create Date: 2026-10-01 13:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0005_tabla_pagos"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "pagos",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("poliza_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("numero_cuota", sa.Integer(), nullable=False),
        sa.Column("monto_usd", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("fecha_vencimiento", sa.Date(), nullable=False),
        sa.Column("fecha_pago", sa.Date(), nullable=True),
        sa.Column("estado", sa.String(length=20), server_default="pendiente", nullable=False),
        sa.Column("metodo_pago", sa.String(length=50), nullable=True),
        sa.Column("comprobante_ref", sa.String(length=100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("estado IN ('pendiente', 'pagado', 'atrasado')", name="chk_estado_pago"),
        sa.ForeignKeyConstraint(["poliza_id"], ["polizas.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("poliza_id", "numero_cuota", name="uq_poliza_cuota"),
    )
    op.create_index(op.f("ix_pagos_poliza_id"), "pagos", ["poliza_id"], unique=False)
    op.create_index(op.f("ix_pagos_estado"), "pagos", ["estado"], unique=False)

    # Población retroactiva automática: generar cuota inicial para pólizas existentes
    op.execute("""
        INSERT INTO pagos (id, poliza_id, numero_cuota, monto_usd, fecha_vencimiento, estado, created_at, updated_at)
        SELECT 
            gen_random_uuid(),
            id,
            1,
            prima_mensual,
            fecha_inicio,
            'pagado',
            NOW(),
            NOW()
        FROM polizas
        WHERE NOT EXISTS (SELECT 1 FROM pagos WHERE pagos.poliza_id = polizas.id);
    """)


def downgrade() -> None:
    op.drop_index(op.f("ix_pagos_estado"), table_name="pagos")
    op.drop_index(op.f("ix_pagos_poliza_id"), table_name="pagos")
    op.drop_table("pagos")
