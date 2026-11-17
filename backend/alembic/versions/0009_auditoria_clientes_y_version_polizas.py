"""Agregar trigger de auditoria en clientes, usuario_id en fn_auditoria y version en polizas.

Revision ID: 0009_auditoria_clientes_y_version_polizas
Revises: 0008_vehiculo_motor_chasis_color
Create Date: 2026-11-17 18:15:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0009_auditoria_clientes_y_version_polizas"
down_revision: str | None = "0008_vehiculo_motor_chasis_color"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "polizas",
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
    )

    op.execute(
        """
        CREATE OR REPLACE FUNCTION fn_auditoria_historial_cambios()
        RETURNS TRIGGER AS $$
        DECLARE
            col_name TEXT;
            val_old TEXT;
            val_new TEXT;
            v_usuario_id UUID;
        BEGIN
            BEGIN
                v_usuario_id := NULLIF(current_setting('sigad.usuario_id', true), '')::uuid;
            EXCEPTION WHEN OTHERS THEN
                v_usuario_id := NULL;
            END;

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
                        INSERT INTO historial_cambios (
                            entidad, entidad_id, campo, valor_anterior, valor_nuevo, usuario_id, fecha
                        )
                        VALUES (
                            TG_TABLE_NAME, NEW.id, col_name, val_old, val_new, v_usuario_id, NOW()
                        );
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
        CREATE TRIGGER trg_audit_clientes
        AFTER UPDATE ON clientes
        FOR EACH ROW
        EXECUTE FUNCTION fn_auditoria_historial_cambios();
        """
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS trg_audit_clientes ON clientes;")

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

    op.drop_column("polizas", "version")
