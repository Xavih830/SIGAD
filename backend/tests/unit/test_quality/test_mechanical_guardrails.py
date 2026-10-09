"""Tests de arquitectura y guardrails AST mecánicos (Anti-Magic Strings y Zero Scattering).

Verifica estáticamente que:
1. Ningún archivo en `backend/app/` o `lib/` contenga URLs crudas hardcodeadas hacia `/api/v1/`
   fuera de las fuentes canónicas de verdad (`api_endpoints.dart` y routers de FastAPI).
2. Los repositorios de Flutter consuman estrictamente `ApiEndpoints` en lugar de literales de ruta.
3. No se hardcodeen límites de tamaño ni timeouts fuera de `app.core.constants` y `AppConstants`.
"""

from pathlib import Path
import re
import pytest

REPO_ROOT = Path(__file__).resolve().parents[4]
BACKEND_APP = REPO_ROOT / "backend" / "app"
FLUTTER_LIB = REPO_ROOT / "lib"


def test_flutter_repositories_use_canonical_api_endpoints():
    """Verifica que ningún repositorio en lib/core/repositories/ use strings crudos para rutas /api/v1/."""
    repos_dir = FLUTTER_LIB / "core" / "repositories"
    assert repos_dir.is_dir(), f"No se encontró el directorio de repositorios en {repos_dir}"

    raw_api_pattern = re.compile(r"['\"]/api/v1/[^'\"]*['\"]")

    violations = []
    for dart_file in repos_dir.glob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")
        matches = raw_api_pattern.findall(content)
        if matches:
            violations.append(f"{dart_file.name}: {matches}")

    assert not violations, (
        f"Se encontraron rutas mágicas crudas en repositorios de Flutter. "
        f"Deben consumir ApiEndpoints.<constante_o_metodo> estrictamente:\n" + "\n".join(violations)
    )


def test_no_magic_file_size_limits_hardcoded_in_backend_endpoints():
    """Verifica que ningún endpoint en backend/app/api/v1/endpoints/ hardcodee 15 * 1024 * 1024 directamente."""
    endpoints_dir = BACKEND_APP / "api" / "v1" / "endpoints"
    assert endpoints_dir.is_dir()

    magic_size_pattern = re.compile(r"(15\s*\*\s*1024\s*\*\s*1024|15728640)")

    violations = []
    for py_file in endpoints_dir.glob("*.py"):
        content = py_file.read_text(encoding="utf-8")
        matches = magic_size_pattern.findall(content)
        if matches:
            violations.append(f"{py_file.name}: {matches}")

    assert not violations, (
        "Se encontraron tamaños máximos de archivo mágicos en endpoints del backend. "
        "Deben importar MAX_DOCUMENT_SIZE_BYTES de app.core.constants:\n" + "\n".join(violations)
    )


def test_flutter_network_no_hardcoded_endpoint_magic_strings_outside_registry():
    """Verifica que las vistas y widgets no contengan literales de rutas /api/v1/."""
    features_dir = FLUTTER_LIB / "features"
    assert features_dir.is_dir()

    raw_api_pattern = re.compile(r"['\"]/api/v1/[^'\"]+['\"]")

    violations = []
    for dart_file in features_dir.rglob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")
        matches = raw_api_pattern.findall(content)
        if matches:
            violations.append(f"{dart_file.relative_to(FLUTTER_LIB)}: {matches}")

    assert not violations, (
        "Se encontraron rutas de API crudas en widgets/vistas de Flutter. "
        "El acceso a red debe ser exclusivamente a través de repositorios y ApiEndpoints:\n"
        + "\n".join(violations)
    )


def test_declarative_code_smells_compliance():
    """Ejecuta las reglas de olores declarativas de .agents/rules/code_smells_config.yml sobre el repositorio."""
    import yaml

    config_path = REPO_ROOT / ".agents" / "rules" / "code_smells_config.yml"
    assert config_path.is_file(), f"No se encontró el archivo de configuración {config_path}"

    with open(config_path, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    rules = config.get("rules", [])
    violations = []

    for rule in rules:
        pattern_str = rule.get("pattern_regex")
        if not pattern_str:
            continue

        compiled_regex = re.compile(pattern_str)
        languages = rule.get("languages", [])

        scope_path = rule.get("scope_path")

        if "dart" in languages:
            target_files = (
                REPO_ROOT.glob(scope_path) if scope_path else FLUTTER_LIB.rglob("*.dart")
            )
            for dart_file in target_files:
                if not dart_file.is_file():
                    continue
                content = dart_file.read_text(encoding="utf-8")
                matches = compiled_regex.findall(content)
                if matches:
                    violations.append(
                        f"[{rule['id']}] {dart_file.relative_to(REPO_ROOT)}: {matches}"
                    )

        if "python" in languages:
            target_files = (
                REPO_ROOT.glob(scope_path) if scope_path else BACKEND_APP.rglob("*.py")
            )
            for py_file in target_files:
                if not py_file.is_file():
                    continue
                if rule["id"] == "smell-python-magic-file-size" and py_file.name == "constants.py":
                    continue
                content = py_file.read_text(encoding="utf-8")
                matches = compiled_regex.findall(content)
                if matches:
                    violations.append(
                        f"[{rule['id']}] {py_file.relative_to(REPO_ROOT)}: {matches}"
                    )

    assert not violations, (
        "Violaciones detectadas según .agents/rules/code_smells_config.yml:\n"
        + "\n".join(violations)
    )


