"""Agregar columna direccion a clientes.

Revision ID: 0010_cliente_direccion
Revises: 0009_audit_clientes_polizas
Create Date: 2026-11-19 15:50:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0010_cliente_direccion"
down_revision: str | None = "0009_audit_clientes_polizas"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("clientes", sa.Column("direccion", sa.String(500), nullable=True))


def downgrade() -> None:
    op.drop_column("clientes", "direccion")
