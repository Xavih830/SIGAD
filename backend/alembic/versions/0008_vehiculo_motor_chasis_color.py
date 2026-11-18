"""Agregar motor, chasis y color a vehiculos con indice unico parcial sobre chasis.

Revision ID: 0008_vehiculo_motor_chasis_color
Revises: 0007_esquemas_poliza
Create Date: 2026-10-21 21:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0008_vehiculo_motor_chasis_color"
down_revision: str | None = "0007_esquemas_poliza"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("vehiculos", sa.Column("motor", sa.String(30), nullable=True))
    op.add_column("vehiculos", sa.Column("chasis", sa.String(30), nullable=True))
    op.add_column("vehiculos", sa.Column("color", sa.String(30), nullable=True))

    op.create_index(
        "ux_vehiculos_chasis",
        "vehiculos",
        ["chasis"],
        unique=True,
        postgresql_where=sa.text("chasis IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("ux_vehiculos_chasis", table_name="vehiculos")
    op.drop_column("vehiculos", "color")
    op.drop_column("vehiculos", "chasis")
    op.drop_column("vehiculos", "motor")
