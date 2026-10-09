"""Verificación de cabeceras de seguridad HTTP y aislamiento en Caddy."""

from tests.integration.test_caddy_headers import (
    test_caddy_routing_isolation,
    test_security_headers_in_caddyfile,
)

__all__ = ["test_security_headers_in_caddyfile", "test_caddy_routing_isolation"]
