"""TEST: Caddy Reverse Proxy Security Headers Verification.

Validates that Caddy reverse proxy enforces strict transport security,
anti-clickjacking, content type nosniff, and strict CSP policies.
"""

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

    # 1. HSTS (HTTP Strict Transport Security)
    assert "Strict-Transport-Security" in content
    assert "max-age=31536000" in content
    assert "includeSubDomains" in content
    assert "preload" in content

    # 2. X-Content-Type-Options (Anti-MIME Sniffing)
    assert 'X-Content-Type-Options "nosniff"' in content or "X-Content-Type-Options nosniff" in content

    # 3. X-Frame-Options (Anti-Clickjacking)
    assert 'X-Frame-Options "DENY"' in content or "X-Frame-Options DENY" in content

    # 4. Content-Security-Policy (CSP)
    assert "Content-Security-Policy" in content
    assert "default-src 'self'" in content

    # 5. Referrer-Policy
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
