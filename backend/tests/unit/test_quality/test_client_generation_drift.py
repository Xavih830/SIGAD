"""Validación de alineación de modelos de cliente Dart con el contrato OpenAPI."""

import json
from pathlib import Path
import re
import pytest


def test_dart_models_align_with_openapi_schemas():
    """Verify that Dart models parse and expose all essential fields from OpenAPI schemas."""
    backend_dir = Path(__file__).resolve().parents[3]
    repo_root = backend_dir.parent
    openapi_file = repo_root / "openapi.json"
    flutter_models_dir = repo_root / "lib" / "core" / "models"

    assert openapi_file.exists(), "openapi.json must exist"
    assert flutter_models_dir.exists(), "lib/core/models directory must exist"

    with open(openapi_file, "r", encoding="utf-8") as f:
        schema = json.load(f)

    schemas = schema.get("components", {}).get("schemas", {})

    assert "VehiculoResponse" in schemas
    vehiculo_props = set(schemas["VehiculoResponse"].get("properties", {}).keys())
    assert {"placa", "marca", "modelo", "anio"}.issubset(vehiculo_props)

    vehicle_dart = (flutter_models_dir / "vehicle_model.dart").read_text(encoding="utf-8")
    for field in ["placa", "marca", "modelo", "anio"]:
        assert f"json['{field}']" in vehicle_dart or f'json["{field}"]' in vehicle_dart, (
            f"vehicle_model.dart does not deserialize OpenAPI field '{field}'"
        )

    assert "PolizaResponse" in schemas
    poliza_props = set(schemas["PolizaResponse"].get("properties", {}).keys())
    assert {"numero_poliza", "estado", "fecha_inicio", "fecha_fin", "prima_mensual", "valor_asegurado"}.issubset(
        poliza_props
    )

    policy_dart = (flutter_models_dir / "policy_model.dart").read_text(encoding="utf-8")
    for field in ["numero_poliza", "estado", "fecha_inicio", "fecha_fin", "prima_mensual", "valor_asegurado"]:
        assert field in policy_dart, (
            f"policy_model.dart does not reference OpenAPI field '{field}'"
        )

    assert "LoginRequest" in schemas
    assert "TokenResponse" in schemas
    token_props = set(schemas["TokenResponse"].get("properties", {}).keys())
    assert {"access_token", "refresh_token", "token_type", "user"}.issubset(token_props)

    user_dart = (flutter_models_dir / "user_model.dart").read_text(encoding="utf-8")
    assert "rol" in user_dart or "role" in user_dart
    assert "email" in user_dart
