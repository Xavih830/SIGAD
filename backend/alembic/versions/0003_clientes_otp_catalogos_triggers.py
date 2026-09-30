"""Clientes OTP, codigos de vinculacion y catalogos relacionales (talleres y asistencias).

Revision ID: 0003
Revises: 0002
Create Date: 2026-09-30
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Tabla: codigos_vinculacion ──────────────────────────────
    op.create_table(
        "codigos_vinculacion",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("cliente_id", UUID(as_uuid=True), sa.ForeignKey("clientes.id", ondelete="CASCADE"), nullable=False),
        sa.Column("codigo_hmac", sa.String(64), nullable=False),
        sa.Column("expira_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumido", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("intentos_fallidos", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_codigos_vinculacion_cliente_id", "codigos_vinculacion", ["cliente_id"])
    op.create_index("ix_codigos_vinculacion_cliente_consumido", "codigos_vinculacion", ["cliente_id", "consumido"])

    # ── Tabla: talleres ──────────────────────────────────────────
    op.create_table(
        "talleres",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("nombre", sa.String(255), nullable=False),
        sa.Column("direccion", sa.String(255), nullable=False),
        sa.Column("telefono", sa.String(50), nullable=False),
        sa.Column("ciudad", sa.String(100), nullable=False),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_talleres_ciudad", "talleres", ["ciudad"])
    op.create_index("ix_talleres_activo", "talleres", ["activo"])

    # ── Tabla: asistencias ───────────────────────────────────────
    op.create_table(
        "asistencias",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("titulo", sa.String(255), nullable=False),
        sa.Column("descripcion", sa.Text(), nullable=False),
        sa.Column("telefono_emergencia", sa.String(50), nullable=False),
        sa.Column("icono", sa.String(100), nullable=False),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_asistencias_activo", "asistencias", ["activo"])

    # ── Seed data inicial para talleres y asistencias ───────────
    op.execute(
        sa.text("""
        INSERT INTO talleres (nombre, direccion, telefono, ciudad, activo)
        VALUES 
            ('Taller Central Guayaquil', 'Av. Juan Tanca Marengo Km 4.5', '04-2598700', 'Guayaquil', true),
            ('AutoMecánica Los Ceibos', 'Av. del Bombero Km 6.5', '04-2854120', 'Guayaquil', true),
            ('Taller Autorizado Quito Norte', 'Av. Galo Plaza Lasso N54-20', '02-2489000', 'Quito', true),
            ('Servicio Mecánico Cuenca Sur', 'Av. Huayna Cápac y González Suárez', '07-4089200', 'Cuenca', true);
        """)
    )

    op.execute(
        sa.text("""
        INSERT INTO asistencias (titulo, descripcion, telefono_emergencia, icono, activo)
        VALUES
            ('Grúa y Remolque', 'Traslado de vehículo averiado o siniestrado hasta el taller autorizado más cercano.', '1800-757-348', 'local_shipping', true),
            ('Auxilio Mecánico Rápido', 'Paso de corriente, cambio de llanta y cerrajería vial de emergencia.', '1800-757-348', 'build', true),
            ('Ambulancia y Emergencia Médica', 'Atención prehospitalaria y traslado médico inmediato en caso de siniestro.', '911', 'emergency', true),
            ('Asesoría Legal In Situ', 'Acompañamiento legal inmediato ante la autoridad de tránsito competente.', '1800-757-349', 'explore', true);
        """)
    )


def downgrade() -> None:
    op.drop_table("asistencias")
    op.drop_table("talleres")
    op.drop_table("codigos_vinculacion")
