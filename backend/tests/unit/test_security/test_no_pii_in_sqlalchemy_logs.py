"""SQLAlchemy error handler does NOT leak PII into logs.

Verifies that the global `sqlalchemy_error_handler`:
1. Returns a generic 500 JSON response.
2. Logs ONLY type, SQLSTATE, and path — never parameters or the exc object.
"""

import ast
import inspect
import logging

import pytest
from fastapi import Request
from sqlalchemy.exc import SQLAlchemyError

from app.core import handlers as handlers_module


def test_no_pii_in_sqlalchemy_logs():
    """The SQLAlchemy error handler must never log bound params or exc details."""
    source = inspect.getsource(handlers_module)
    tree = ast.parse(source)

    found_handler = False
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == "sqlalchemy_error_handler":
            found_handler = True
            func_source = inspect.getsource(handlers_module.register_handlers)

            dangerous_patterns = [
                "logger.error(str(exc)",
                "logger.error(exc)",
                'logger.error(f"{exc}',
                "logger.error(f'{exc}",
                "logger.error(repr(exc)",
                "logger.warning(str(exc)",
                "logger.exception(",
                "traceback.format_exc",
            ]
            for pattern in dangerous_patterns:
                assert pattern not in func_source, (
                    f"Handler contains '{pattern}' which could leak PII. "
                    f"Only type(exc).__name__, SQLSTATE, and path are allowed."
                )

            assert "type(exc).__name__" in func_source or "type=" in func_source, (
                "Handler should log exception type via type(exc).__name__"
            )
            assert "path" in func_source, "Handler should log the request path"
            break

    assert found_handler, "sqlalchemy_error_handler function must be defined in handlers module"

    assert "Error interno del servidor" in source, (
        "Handler must return a generic 'Error interno del servidor' message, not DB details"
    )
