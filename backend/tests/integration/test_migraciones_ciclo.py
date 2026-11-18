"""Prueba del ciclo completo de migraciones Alembic (upgrade y downgrade)."""

import os
import subprocess
import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine, text


def _verificar_rol_enum_existe(db_sync_url: str) -> bool:
    """Consulta el catalogo pg_type para determinar si el tipo rol_enum existe."""
    engine = create_engine(db_sync_url)
    with engine.connect() as conn:
        result = conn.execute(
            text("SELECT 1 FROM pg_type WHERE typname = 'rol_enum'")
        )
        return result.scalar() is not None


@pytest.mark.migraciones
def test_ciclo_completo_upgrade_downgrade_migraciones():
    """Verifica que el ciclo de migraciones (downgrade base, upgrade head, downgrade -1, upgrade head) es determinista."""
    db_sync_url = os.environ.get(
        "DATABASE_SYNC_URL",
        "postgresql://sigad:sigad_dev_2024@localhost:5432/sigad_test_db",
    )
    test_db_url = os.environ.get("TEST_DATABASE_URL", "")
    if "postgres:5432" in test_db_url and "localhost" in db_sync_url:
        db_sync_url = db_sync_url.replace("localhost:5432", "postgres:5432")

    backend_dir = Path(__file__).resolve().parents[2]
    alembic_env = os.environ.copy()
    alembic_env["DATABASE_SYNC_URL"] = db_sync_url

    def _run_alembic(command_args: list[str]) -> subprocess.CompletedProcess:
        res = subprocess.run(
            [sys.executable, "-m", "alembic", *command_args],
            cwd=backend_dir,
            env=alembic_env,
            capture_output=True,
            text=True,
        )
        assert res.returncode == 0, f"Alembic {' '.join(command_args)} falló:\n{res.stderr}\n{res.stdout}"
        return res

    # 1. Downgrade a base
    _run_alembic(["downgrade", "base"])
    assert not _verificar_rol_enum_existe(db_sync_url), "rol_enum no debe existir tras downgrade base"

    # 2. Upgrade a head
    _run_alembic(["upgrade", "head"])
    assert _verificar_rol_enum_existe(db_sync_url), "rol_enum debe existir tras upgrade head"

    # 3. Downgrade -1
    _run_alembic(["downgrade", "-1"])

    # 4. Upgrade head final
    _run_alembic(["upgrade", "head"])
    assert _verificar_rol_enum_existe(db_sync_url), "rol_enum debe existir tras upgrade head final"
