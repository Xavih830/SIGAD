"""Polizas, vehiculos, deducibles, auditoria y triggers.

Revision ID: 0002
Revises: 0001
Create Date: 2026-09-30
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "vehiculos",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("placa", sa.String(10), unique=True, nullable=False),
        sa.Column("marca", sa.String(100), nullable=False),
        sa.Column("modelo", sa.String(100), nullable=False),
        sa.Column("anio", sa.Integer(), nullable=False),
        sa.Column("cliente_id", UUID(as_uuid=True), sa.ForeignKey("clientes.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_vehiculos_cliente_id", "vehiculos", ["cliente_id"])
    op.create_index("ix_vehiculos_placa", "vehiculos", ["placa"])

    op.create_table(
        "inspecciones",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("vehiculo_id", UUID(as_uuid=True), sa.ForeignKey("vehiculos.id", ondelete="CASCADE"), nullable=False),
        sa.Column("fecha", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("kilometraje", sa.Integer(), nullable=False),
        sa.Column("observaciones", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_inspecciones_vehiculo_id", "inspecciones", ["vehiculo_id"])

    op.create_table(
        "polizas",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("numero_poliza", sa.String(50), unique=True, nullable=False),
        sa.Column("cliente_id", UUID(as_uuid=True), sa.ForeignKey("clientes.id", ondelete="CASCADE"), nullable=False),
        sa.Column("vehiculo_id", UUID(as_uuid=True), sa.ForeignKey("vehiculos.id", ondelete="CASCADE"), nullable=False),
        sa.Column("inspeccion_id", UUID(as_uuid=True), sa.ForeignKey("inspecciones.id", ondelete="SET NULL"), nullable=True),
        sa.Column("fecha_inicio", sa.Date(), nullable=False),
        sa.Column("fecha_fin", sa.Date(), nullable=False),
        sa.Column(
            "estado",
            sa.Enum("pendiente", "activa", "por_vencer", "vencida", "cancelada", name="estado_poliza_enum"),
            nullable=False,
        ),
        sa.Column("valor_asegurado", sa.Numeric(12, 2), nullable=False),
        sa.Column("prima_mensual", sa.Numeric(10, 2), nullable=False),
        sa.Column("kilometraje_emision", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_polizas_cliente_id", "polizas", ["cliente_id"])
    op.create_index("ix_polizas_vehiculo_id", "polizas", ["vehiculo_id"])
    op.create_index("ix_polizas_numero_poliza", "polizas", ["numero_poliza"])
    op.create_index("ix_polizas_estado", "polizas", ["estado"])

    op.create_table(
        "deducibles",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("poliza_id", UUID(as_uuid=True), sa.ForeignKey("polizas.id", ondelete="CASCADE"), nullable=False),
        sa.Column(
            "tipo_siniestro",
            sa.Enum("general", "robo", "choque", "perdida_total", name="tipo_siniestro_enum"),
            nullable=False,
        ),
        sa.Column("porcentaje_valor", sa.Numeric(5, 2), nullable=False),
        sa.Column("monto_minimo_usd", sa.Numeric(10, 2), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_deducibles_poliza_id", "deducibles", ["poliza_id"])

    op.create_table(
        "coberturas",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("poliza_id", UUID(as_uuid=True), sa.ForeignKey("polizas.id", ondelete="CASCADE"), nullable=False),
        sa.Column("nombre", sa.String(255), nullable=False),
        sa.Column("monto", sa.Numeric(12, 2), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_coberturas_poliza_id", "coberturas", ["poliza_id"])

    op.create_table(
        "historial_cambios",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("entidad", sa.String(50), nullable=False),
        sa.Column("entidad_id", UUID(as_uuid=True), nullable=False),
        sa.Column("campo", sa.String(100), nullable=False),
        sa.Column("valor_anterior", sa.Text(), nullable=True),
        sa.Column("valor_nuevo", sa.Text(), nullable=True),
        sa.Column("usuario_id", UUID(as_uuid=True), sa.ForeignKey("usuarios.id", ondelete="SET NULL"), nullable=True),
        sa.Column("fecha", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_historial_cambios_entidad_entidad_id", "historial_cambios", ["entidad", "entidad_id"])

    op.execute(
        """
        CREATE OR REPLACE FUNCTION fn_auditoria_historial_cambios()
        RETURNS TRIGGER AS $$
        DECLARE
            col_name TEXT;
            val_old TEXT;
            val_new TEXT;
        BEGIN
            IF (TG_OP = 'UPDATE') THEN
                FOR col_name IN
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name = TG_TABLE_NAME
                      AND column_name NOT IN ('updated_at', 'created_at')
                LOOP
                    EXECUTE format('SELECT ($1).%I::text, ($2).%I::text', col_name, col_name)
                    USING OLD, NEW
                    INTO val_old, val_new;
                    
                    IF (val_old IS DISTINCT FROM val_new) THEN
                        INSERT INTO historial_cambios (entidad, entidad_id, campo, valor_anterior, valor_nuevo, fecha)
                        VALUES (TG_TABLE_NAME, NEW.id, col_name, val_old, val_new, NOW());
                    END IF;
                END LOOP;
                RETURN NEW;
            END IF;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """
    )

    op.execute(
        """
        CREATE TRIGGER trg_audit_polizas
        AFTER UPDATE ON polizas
        FOR EACH ROW
        EXECUTE FUNCTION fn_auditoria_historial_cambios();
        """
    )

    op.execute(
        """
        CREATE TRIGGER trg_audit_vehiculos
        AFTER UPDATE ON vehiculos
        FOR EACH ROW
        EXECUTE FUNCTION fn_auditoria_historial_cambios();
        """
    )

    op.execute(
        """
        INSERT INTO deducibles (id, poliza_id, tipo_siniestro, porcentaje_valor, monto_minimo_usd, created_at)
        SELECT 
            gen_random_uuid(), 
            id, 
            'general', 
            10.0, 
            200.0, 
            NOW()
        FROM polizas
        WHERE NOT EXISTS (
            SELECT 1 FROM deducibles WHERE deducibles.poliza_id = polizas.id
        );
        """
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS trg_audit_vehiculos ON vehiculos;")
    op.execute("DROP TRIGGER IF EXISTS trg_audit_polizas ON polizas;")
    op.execute("DROP FUNCTION IF EXISTS fn_auditoria_historial_cambios();")

    op.drop_table("coberturas")
    op.drop_table("deducibles")
    op.drop_table("polizas")
    op.drop_table("inspecciones")
    op.drop_table("vehiculos")
    op.drop_table("historial_cambios")

    sa.Enum(name="tipo_siniestro_enum").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="estado_poliza_enum").drop(op.get_bind(), checkfirst=True)
