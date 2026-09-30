"""TEST: OpenAPI export with strict socket isolation.

Verifies that:
1. Export script runs without performing any external network or database connections.
2. Socket instantiation raises RuntimeError under defensive blocking.
3. The exported OpenAPI schema contains valid metadata, paths, and components.
"""

from pathlib import Path
import socket
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
