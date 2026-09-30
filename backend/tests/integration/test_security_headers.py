"""TEST 27: Security Headers compliance verification (alias to test_caddy_headers)."""

from tests.integration.test_caddy_headers import (
    test_caddy_routing_isolation,
    test_security_headers_in_caddyfile,
)

__all__ = ["test_security_headers_in_caddyfile", "test_caddy_routing_isolation"]
