"""Auth initial — usuarios, clientes, sesiones_auth + seed data.

Revision ID: 0001
Revises: None
Create Date: 2026-09-30
"""
from typing import Sequence, Union
from uuid import uuid4

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

from argon2 import PasswordHasher

# revision identifiers, used by Alembic.
revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Argon2id hasher with the same parameters as the app
ph = PasswordHasher(memory_cost=19456, time_cost=2, parallelism=1)


def upgrade() -> None:
    # ── Tabla: usuarios ─────────────────────────────────────────
    op.create_table(
        "usuarios",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("email", sa.String(255), unique=True, nullable=False),
        sa.Column("password_hash", sa.String(512), nullable=False),
        sa.Column("nombre", sa.String(255), nullable=False),
        sa.Column("rol", sa.Enum("admin", "agente", "cliente", name="rol_enum"), nullable=False),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    # ── Tabla: clientes ─────────────────────────────────────────
    op.create_table(
        "clientes",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("identificacion", sa.String(13), unique=True, nullable=False),
        sa.Column("nombres", sa.String(255), nullable=False),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("telefono", sa.String(20), nullable=True),
        sa.Column("usuario_id", UUID(as_uuid=True), sa.ForeignKey("usuarios.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    # ── Tabla: sesiones_auth ────────────────────────────────────
    op.create_table(
        "sesiones_auth",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("usuario_id", UUID(as_uuid=True), sa.ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False),
        sa.Column("family_id", UUID(as_uuid=True), nullable=False),
        sa.Column("jti", sa.String(64), unique=True, nullable=False),
        sa.Column("refresh_token_hash", sa.String(512), nullable=False),
        sa.Column("revocado", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("expira_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_sesiones_auth_usuario_revocado", "sesiones_auth", ["usuario_id", "revocado"])

    # ── Seed data ───────────────────────────────────────────────
    usuarios_table = sa.table(
        "usuarios",
        sa.column("id", UUID(as_uuid=True)),
        sa.column("email", sa.String),
        sa.column("password_hash", sa.String),
        sa.column("nombre", sa.String),
        sa.column("rol", sa.String),
        sa.column("activo", sa.Boolean),
    )

    admin_id = uuid4()
    cliente_user_id = uuid4()

    op.bulk_insert(usuarios_table, [
        {
            "id": admin_id,
            "email": "admin@sigad.ec",
            "password_hash": ph.hash("Admin#SIGAD24"),
            "nombre": "Administrador del Sistema",
            "rol": "admin",
            "activo": True,
        },
        {
            "id": cliente_user_id,
            "email": "m.leon@hotmail.com",
            "password_hash": ph.hash("Maria#2024"),
            "nombre": "María José León Andrade",
            "rol": "cliente",
            "activo": True,
        },
    ])

    clientes_table = sa.table(
        "clientes",
        sa.column("id", UUID(as_uuid=True)),
        sa.column("identificacion", sa.String),
        sa.column("nombres", sa.String),
        sa.column("email", sa.String),
        sa.column("telefono", sa.String),
        sa.column("usuario_id", UUID(as_uuid=True)),
    )

    op.bulk_insert(clientes_table, [
        {
            "id": uuid4(),
            "identificacion": "0923456789",
            "nombres": "María José León Andrade",
            "email": "m.leon@hotmail.com",
            "telefono": "0976543210",
            "usuario_id": cliente_user_id,
        },
    ])


def downgrade() -> None:
    op.drop_index("ix_sesiones_auth_usuario_revocado", table_name="sesiones_auth")
    op.drop_table("sesiones_auth")
    op.drop_table("clientes")
    op.drop_table("usuarios")
    sa.Enum(name="rol_enum").drop(op.get_bind(), checkfirst=True)
