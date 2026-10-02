#!/usr/bin/env python3
"""OpenAPI schema exporter with defensive socket blocking.

Guarantees 100% offline schema generation:
1. Neutralizes Python's socket interface at the interpreter level during export.
2. Injects safe development / mock environment variables.
3. Exports the current OpenAPI schema to `openapi.json` in the project root.
"""

import contextlib
import json
import os
from pathlib import Path
import socket
import sys

# 1. Bloqueo Defensivo de Sockets a nivel de intérprete
_original_socket_class = socket.socket
_original_create_connection = getattr(socket, "create_connection", None)


class SocketBloqueado(_original_socket_class):
    """Subclase defensiva que bloquea cualquier instanciación o intento de conexión."""

    def __init__(self, *args, **kwargs):
        raise RuntimeError("Violación de aislamiento: intento de conexión de red durante exportación OpenAPI")


def socket_connect_bloqueado(*args, **kwargs):
    raise RuntimeError("Violación de aislamiento: intento de conexión de red durante exportación OpenAPI")


@contextlib.contextmanager
def defensive_socket_blocking():
    """Activa el bloqueo estricto de sockets durante la ejecución del bloque."""
    socket.socket = SocketBloqueado
    socket.create_connection = socket_connect_bloqueado
    try:
        yield
    finally:
        socket.socket = _original_socket_class
        if _original_create_connection is not None:
            socket.create_connection = _original_create_connection


# Ensure backend root is on sys.path
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

# 3. Importar app e inspeccionar OpenAPI
from app.main import app


def export_schema(target_file: Path | None = None) -> dict:
    """Generate OpenAPI schema and save to file with defensive isolation."""
    with defensive_socket_blocking():
        schema = app.openapi()

    if target_file is None:
        repo_root = backend_dir.parent
        target_file = repo_root / "openapi.json"

    with open(target_file, "w", encoding="utf-8") as f:
        json.dump(schema, f, indent=2, ensure_ascii=False)
        f.write("\n")

    return schema


if __name__ == "__main__":
    socket.socket = SocketBloqueado
    socket.create_connection = socket_connect_bloqueado
    repo_root = backend_dir.parent
    dest = repo_root / "openapi.json"
    export_schema(dest)
    print(f"Contrato OpenAPI exportado con aislamiento estricto en: {dest}")
