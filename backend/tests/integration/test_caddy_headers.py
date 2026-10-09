"""Validación de cabeceras de seguridad del reverse proxy Caddy."""

from pathlib import Path
import re
import pytest


def test_security_headers_in_caddyfile():
    """Verify that Caddyfile configures all essential production security headers."""
    backend_dir = Path(__file__).resolve().parents[2]
    repo_root = backend_dir.parent
    caddyfile_path = repo_root / "Caddyfile"

    assert caddyfile_path.exists(), f"Missing Caddyfile at {caddyfile_path}"
    content = caddyfile_path.read_text(encoding="utf-8")

    assert "Strict-Transport-Security" in content
    assert "max-age=31536000" in content
    assert "includeSubDomains" in content
    assert "preload" in content

    assert 'X-Content-Type-Options "nosniff"' in content or "X-Content-Type-Options nosniff" in content

    assert 'X-Frame-Options "DENY"' in content or "X-Frame-Options DENY" in content

    assert "Content-Security-Policy" in content
    assert "default-src 'self'" in content

    assert "Referrer-Policy" in content
    assert "strict-origin-when-cross-origin" in content



def test_caddy_routing_isolation():
    """Verify that static files and downloads are strictly isolated."""
    backend_dir = Path(__file__).resolve().parents[2]
    repo_root = backend_dir.parent
    caddyfile_path = repo_root / "Caddyfile"

    content = caddyfile_path.read_text(encoding="utf-8")
    assert "/srv/flutter_web" in content
    assert "handle /descargas/*" in content
    assert "/srv/downloads" in content
