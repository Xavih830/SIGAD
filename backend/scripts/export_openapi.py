#!/usr/bin/env python3
"""Exportador fuera de línea del contrato OpenAPI con aislamiento defensivo de red."""

import contextlib
import json
import os
import socket
import sys
from pathlib import Path

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


backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

_VARIABLES_FICTICIAS: dict[str, str] = {
    "DATABASE_URL": "postgresql+asyncpg://openapi:openapi@invalid.local:5432/openapi",
    "DATABASE_SYNC_URL": "postgresql://openapi:openapi@invalid.local:5432/openapi",
    "JWT_SECRET_KEY": "openapi-export-dummy-secret-0000000000000000",
    "OTP_SECRET_KEY_ACTUAL": "openapi-export-dummy-otp-actual-00000000000",
    "OTP_SECRET_KEY_ANTERIOR": "openapi-export-dummy-otp-anterior-000000000",
    "SMTP_HOST": "invalid.local",
    "SMTP_PORT": "1025",
    "SMTP_FROM_EMAIL": "noreply@invalid.local",
    "UPLOAD_DIR": "uploads",
}

for k, v in _VARIABLES_FICTICIAS.items():
    os.environ.setdefault(k, v)

os.environ["ENVIRONMENT"] = "development"


def export_schema(target_file: Path | None = None) -> dict:
    """Generate OpenAPI schema and save to file with defensive isolation."""
    with defensive_socket_blocking():
        from app.main import app

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
    if len(sys.argv) > 1:
        dest = Path(sys.argv[1]).resolve()
    else:
        dest = repo_root / "openapi.json"
    export_schema(dest)
    print(f"Contrato OpenAPI exportado con aislamiento estricto en: {dest}")
