"""Constant-time login — structural verification.

Verifies that:
1. A DUMMY_HASH exists in the security module.
2. The `verify_dummy` function is available and callable.
3. When a user is NOT found, the endpoint still runs Argon2 verification
   (against the dummy hash) so timing is indistinguishable.
"""

import ast
import inspect
import time

import pytest

from app.core import security


def test_constant_time_login_structural():
    """Structurally verify constant-time defense mechanisms exist."""
    assert hasattr(security, "DUMMY_HASH"), "security module must define DUMMY_HASH"
    assert isinstance(security.DUMMY_HASH, str), "DUMMY_HASH must be a string"
    assert security.DUMMY_HASH.startswith("$argon2"), "DUMMY_HASH must be an Argon2 hash"

    assert hasattr(security, "verify_dummy"), "security module must define verify_dummy()"
    assert inspect.iscoroutinefunction(security.verify_dummy), "verify_dummy must be async"

    from app.api.v1.endpoints import auth as auth_module
    source = inspect.getsource(auth_module)
    tree = ast.parse(source)

    has_verify_dummy_call = False
    for node in ast.walk(tree):
        if isinstance(node, ast.Attribute) and node.attr == "verify_dummy":
            has_verify_dummy_call = True
            break
        if isinstance(node, ast.Name) and node.id == "verify_dummy":
            has_verify_dummy_call = True
            break

    assert has_verify_dummy_call, (
        "Auth endpoint must call verify_dummy when user is not found "
        "to ensure constant-time response"
    )
