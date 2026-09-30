"""TEST: OpenAPI Schema Drift Detection.

Guarantees that the committed `openapi.json` contract matches the live FastAPI
application router definition with zero discrepancies.
"""

import json
from pathlib import Path
import pytest

from app.main import app


def test_openapi_contract_no_drift():
    """Verify that committed openapi.json matches live app.openapi() without drift."""
    backend_dir = Path(__file__).resolve().parents[3]
    repo_root = backend_dir.parent
    openapi_file = repo_root / "openapi.json"

    assert openapi_file.exists(), (
        f"Missing {openapi_file}. Run `python backend/scripts/export_openapi.py` to generate it."
    )

    with open(openapi_file, "r", encoding="utf-8") as f:
        committed_schema = json.load(f)

    live_schema = app.openapi()

    # 1. Compare Paths
    committed_paths = set(committed_schema.get("paths", {}).keys())
    live_paths = set(live_schema.get("paths", {}).keys())

    missing_in_file = live_paths - committed_paths
    obsolete_in_file = committed_paths - live_paths

    assert not missing_in_file, (
        f"OpenAPI drift detected! The following new paths are not in openapi.json: {missing_in_file}. "
        f"Run `python backend/scripts/export_openapi.py` to synchronize."
    )
    assert not obsolete_in_file, (
        f"OpenAPI drift detected! The following obsolete paths remain in openapi.json: {obsolete_in_file}. "
        f"Run `python backend/scripts/export_openapi.py` to synchronize."
    )

    # 2. Compare Methods per Path
    for path in live_paths:
        live_methods = set(live_schema["paths"][path].keys())
        committed_methods = set(committed_schema["paths"][path].keys())
        assert live_methods == committed_methods, (
            f"Method drift for path {path}: live={live_methods}, committed={committed_methods}"
        )

    # 3. Compare Component Schemas
    committed_components = set(committed_schema.get("components", {}).get("schemas", {}).keys())
    live_components = set(live_schema.get("components", {}).get("schemas", {}).keys())
    assert committed_components == live_components, (
        f"Component schema drift detected: diff={committed_components ^ live_components}"
    )
