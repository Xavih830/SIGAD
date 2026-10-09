"""Architecture tests enforcing Single Source of Truth, Deterministic Configuration, and Radical Fail-Fast.

Directly enforces Rule 9 of AGENTS.md:
- Exactly one canonical .env in project root.
- No duplicate .env in subfolders (e.g. backend/.env).
- Deterministic absolute resolution in SettingsConfigDict (no heuristic relative tuples).
- Strict fail-fast interpolation in docker-compose.yml.
- Strict fail-fast StateError validation in Flutter ApiConfig.
"""

from pathlib import Path
import re
import pytest
from app.core.config import Settings


def test_single_canonical_env_in_root():
    """Verify that .env exists exclusively in the repository root."""
    repo_root = Path(__file__).resolve().parents[4]
    root_env = repo_root / ".env"
    backend_env = repo_root / "backend" / ".env"
    backend_env_example = repo_root / "backend" / ".env.example"

    assert root_env.is_file(), "El archivo canónico .env DEBE existir en la raíz del repositorio"
    assert not root_env.is_symlink(), "El archivo .env en la raíz NO debe ser un enlace simbólico"
    assert not backend_env.exists(), "PROHIBIDO mantener archivos .env duplicados en backend/"
    assert not backend_env_example.exists(), "PROHIBIDO mantener archivos .env.example duplicados en backend/"


def test_settings_config_uses_deterministic_absolute_path():
    """Verify that Settings.model_config['env_file'] is an absolute deterministic Path, not a heuristic tuple."""
    env_file_cfg = Settings.model_config.get("env_file")

    assert not isinstance(env_file_cfg, (list, tuple)), (
        f"PROHIBIDO el uso de tuplas relativas o listas heurísticas en env_file: {env_file_cfg}. "
        "Debe ser una ruta absoluta canónica o None (para Docker os.environ)."
    )

    if env_file_cfg is not None:
        assert isinstance(env_file_cfg, Path), "env_file debe resolverse como un objeto Path canónico"
        assert env_file_cfg.is_absolute(), f"La ruta de env_file debe ser absoluta: {env_file_cfg}"
        assert env_file_cfg.name == ".env", f"env_file debe apuntar a .env: {env_file_cfg}"


def test_docker_compose_enforces_fail_fast_upload_dir():
    """Verify that docker-compose.yml requires UPLOAD_DIR via fail-fast interpolation."""
    repo_root = Path(__file__).resolve().parents[4]
    compose_path = repo_root / "docker-compose.yml"

    assert compose_path.is_file(), "docker-compose.yml debe existir en la raíz"
    content = compose_path.read_text(encoding="utf-8")

    assert "uploads_data:/backend/uploads" not in content, (
        "PROHIBIDO hardcodear la ruta de uploads en docker-compose.yml. "
        "Debe configurarse mediante la variable de entorno con Fail-Fast."
    )

    fail_fast_pattern = re.compile(r"uploads_data:/backend/\$\{UPLOAD_DIR:\?[^}]+\}")
    matches = fail_fast_pattern.findall(content)
    assert len(matches) >= 2, (
        "Tanto api como worker en docker-compose.yml deben usar la sintaxis Fail-Fast "
        "${UPLOAD_DIR:?Variable UPLOAD_DIR es requerida en .env}"
    )


def test_flutter_api_config_enforces_fail_fast():
    """Verify that Flutter's api_config.dart enforces radical fail-fast without magic dev/prod branching."""
    repo_root = Path(__file__).resolve().parents[4]
    api_config_path = repo_root / "lib" / "core" / "config" / "api_config.dart"

    assert api_config_path.is_file(), "api_config.dart debe existir en lib/core/config/"
    content = api_config_path.read_text(encoding="utf-8")

    assert "_hostWeb = 'http://localhost:8000'" not in content, (
        "PROHIBIDO hardcodear _hostWeb en api_config.dart"
    )
    assert "_hostAndroid = 'http://10.0.2.2:8000'" not in content, (
        "PROHIBIDO hardcodear _hostAndroid en api_config.dart"
    )
    assert "kReleaseMode" not in content, (
        "PROHIBIDO bifurcar entornos mágicamente con kReleaseMode en api_config.dart"
    )

    assert "StateError" in content, (
        "api_config.dart DEBE lanzar StateError si API_BASE_URL no está configurada"
    )
    assert "String.fromEnvironment('API_BASE_URL')" in content, (
        "api_config.dart DEBE cargar API_BASE_URL desde el entorno via String.fromEnvironment"
    )


def test_cors_security_not_wildcard_with_credentials():
    """Verify that main.py does not combine allow_origins=['*'] with allow_credentials=True (CWE-942)."""
    repo_root = Path(__file__).resolve().parents[4]
    main_path = repo_root / "backend" / "app" / "main.py"
    content = main_path.read_text(encoding="utf-8")

    assert 'allow_origins=["*"]' not in content, (
        "PROHIBIDO allow_origins=['*'] con allow_credentials=True en CORSMiddleware. "
        "Debe usar settings.CORS_ORIGINS para evitar vulnerabilidad CWE-942."
    )


def test_caddyfile_does_not_expose_mailpit_publicly():
    """Verify that Caddyfile does not expose internal Mailpit debugging interface publicly."""
    repo_root = Path(__file__).resolve().parents[4]
    caddy_path = repo_root / "Caddyfile"
    content = caddy_path.read_text(encoding="utf-8")

    assert "mailpit:8025" not in content, (
        "PROHIBIDO exponer Mailpit en el reverse proxy público de Caddy. "
        "Mailpit contiene OTPs y enlaces de restablecimiento sensibles."
    )


def test_upload_dir_validator_prevents_path_traversal():
    """Verify that Settings.UPLOAD_DIR validator blocks path traversal and reserved directory shadowing."""
    import pytest
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        Settings(UPLOAD_DIR="../etc")

    with pytest.raises(ValidationError):
        Settings(UPLOAD_DIR="app")

    with pytest.raises(ValidationError):
        Settings(UPLOAD_DIR="/root")


def test_client_env_example_has_no_backend_secrets():
    """Verify that .env.client.example contains ONLY public client config and no backend secrets."""
    repo_root = Path(__file__).resolve().parents[4]
    client_env_path = repo_root / ".env.client.example"

    assert client_env_path.is_file(), ".env.client.example debe existir para guiar al frontend"
    content = client_env_path.read_text(encoding="utf-8")

    forbidden_secrets = ["JWT_SECRET", "POSTGRES", "DATABASE_URL", "OTP_SECRET", "ARGON2", "SMTP"]
    for secret in forbidden_secrets:
        assert secret not in content, (
            f"PROHIBIDO incluir {secret} en .env.client.example. "
            "El cliente Flutter NUNCA debe empaquetar secretos de backend."
        )


def test_storage_service_enforces_magic_bytes_and_extensions():
    """Verify that StorageService rejects spoofed MIME types and incompatible file extensions (CWE-434)."""
    import pytest
    from app.services.storage_service import InvalidMimeTypeException, storage_service

    fake_jpeg = b"This is plain text pretending to be a photo"
    with pytest.raises(InvalidMimeTypeException, match="magic bytes"):
        storage_service.save_file(fake_jpeg, "foto.jpg", "image/jpeg")

    valid_pdf_header = b"%PDF-1.4\n%fake-pdf-content"
    with pytest.raises(InvalidMimeTypeException, match="Extensión de archivo"):
        storage_service.save_file(valid_pdf_header, "exploit.php", "application/pdf")


@pytest.mark.asyncio
async def test_seeder_blocks_execution_in_production():
    """Verify that seed_dev_data refuses to populate development default passwords in production (CWE-1188)."""
    from unittest.mock import AsyncMock, patch
    import pytest
    from app.core.config import settings
    from scripts.seed_dev_data import seed_data

    mock_session = AsyncMock()
    with patch.object(settings, "ENVIRONMENT", "production"):
        with pytest.raises(RuntimeError, match="No se puede ejecutar el seeder de desarrollo en un entorno de producción"):
            await seed_data(mock_session)


@pytest.mark.asyncio
async def test_seeder_blocks_execution_on_test_database():
    """Verify that seed_dev_data refuses to populate sigad_test_db to preserve test isolation."""
    from unittest.mock import AsyncMock, MagicMock
    import pytest
    from scripts.seed_dev_data import seed_data

    mock_session = AsyncMock()
    mock_bind = MagicMock()
    mock_bind.url = "postgresql+asyncpg://sigad:sigad_dev_2024@localhost:5432/sigad_test_db"
    mock_session.bind = mock_bind

    with pytest.raises(RuntimeError, match="PROHIBIDO ejecutar el seeder de desarrollo sobre la base de datos de pruebas"):
        await seed_data(mock_session)



def test_dockerfile_enforces_non_root_user():
    """Verify that Dockerfile defines and switches to a non-privileged user (CWE-250 / CIS Benchmark)."""
    repo_root = Path(__file__).resolve().parents[4]
    dockerfile_path = repo_root / "Dockerfile"
    assert dockerfile_path.is_file(), "Dockerfile debe existir en la raíz"

    content = dockerfile_path.read_text(encoding="utf-8")
    assert "USER sigad" in content, "Dockerfile DEBE declarar USER sigad para evitar ejecución como root"
    assert "groupadd" in content and "useradd" in content, "Dockerfile DEBE aprovisionar el usuario sin privilegios"


def test_smtp_password_masked_secretstr():
    """Verify that SMTP_PASSWORD is typed as SecretStr to prevent credential leakage in logs."""
    from pydantic import SecretStr
    field_info = Settings.model_fields.get("SMTP_PASSWORD")
    assert field_info is not None
    assert field_info.annotation is SecretStr or Settings.__annotations__.get("SMTP_PASSWORD") is SecretStr


@pytest.mark.asyncio
async def test_vinculacion_rejects_already_linked_client():
    """Verify that attempting to link an already vinculated client raises 400 to prevent Account Takeover."""
    from unittest.mock import AsyncMock, MagicMock
    import uuid
    from httpx import ASGITransport, AsyncClient
    from app.main import app
    from app.db.session import get_db
    from app.models.cliente import Cliente
    from app.core.rate_limit import rate_limiter
    from tests.factories import vinculacion_payload

    rate_limiter.reset()
    mock_session = AsyncMock()
    mock_cliente = MagicMock(spec=Cliente)
    mock_cliente.usuario_id = uuid.uuid4()
    mock_cliente.identificacion = "0926687856"
    res_cliente = MagicMock()
    res_cliente.scalar_one_or_none.return_value = mock_cliente
    mock_session.execute.return_value = res_cliente

    async def fake_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = fake_get_db
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            resp = await client.post("/api/v1/auth/vinculacion", json=vinculacion_payload(cedula="0926687856"))
            assert resp.status_code == 400
            assert "ya se encuentra vinculado" in resp.json()["detail"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_health_probe_masks_internal_error():
    """Verify that /health does not leak internal error message when database fails (CWE-209)."""
    from unittest.mock import AsyncMock
    from httpx import ASGITransport, AsyncClient
    from app.main import create_app
    from app.db.session import get_db

    mock_session = AsyncMock()
    mock_session.execute.side_effect = Exception("password authentication failed for user secret_user")

    async def fake_get_db():
        yield mock_session

    test_app = create_app()
    test_app.dependency_overrides[get_db] = fake_get_db
    transport = ASGITransport(app=test_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/health")
        assert resp.status_code == 503
        body = resp.json()
        assert "error" not in body, f"Prohibido filtrar mensaje interno en health check: {body}"
        assert body == {"status": "degraded", "database": "disconnected"}

