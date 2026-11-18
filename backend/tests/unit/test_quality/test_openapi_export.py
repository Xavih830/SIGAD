"""TEST: OpenAPI export with strict socket isolation.

Verifies that:
1. Export script runs without performing any external network or database connections.
2. Socket instantiation raises RuntimeError under defensive blocking.
3. The exported OpenAPI schema contains valid metadata, paths, and components.
"""

import socket
from pathlib import Path

import pytest

from scripts.export_openapi import SocketBloqueado, export_schema


def test_defensive_socket_blocks_network():
    """Verify that SocketBloqueado prevents any raw socket instantiation."""
    with pytest.raises(RuntimeError, match="Violación de aislamiento"):
        SocketBloqueado(socket.AF_INET, socket.SOCK_STREAM)


def test_openapi_schema_export_structure(tmp_path):
    """Verify that export_schema creates a valid OpenAPI 3.x schema file."""
    output_file = tmp_path / "test_openapi.json"
    schema = export_schema(target_file=output_file)

    assert output_file.exists()
    assert "openapi" in schema
    assert schema["openapi"].startswith("3.")
    assert "info" in schema
    assert schema["info"]["title"] == "SIGAD API"
    assert "paths" in schema
    assert len(schema["paths"]) > 5
    assert "components" in schema


def test_export_sin_env_usa_variables_ficticias(tmp_path):
    """Verify that export_openapi.py runs cleanly in a clean environment without .env."""
    import json
    import os
    import subprocess
    import sys

    backend_dir = Path(__file__).resolve().parents[3]
    script_path = backend_dir / "scripts" / "export_openapi.py"
    target_json = tmp_path / "exported_openapi.json"

    env = {
        "PATH": os.environ.get("PATH", ""),
        "PYTHONPATH": str(backend_dir),
    }

    result = subprocess.run(
        [sys.executable, str(script_path), str(target_json)],
        cwd=tmp_path,
        env=env,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, f"Script failed with stderr:\n{result.stderr}\nstdout:\n{result.stdout}"
    assert target_json.exists()
    data = json.loads(target_json.read_text(encoding="utf-8"))
    assert "paths" in data

