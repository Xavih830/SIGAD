"""Root conftest for SIGAD backend test suite.

Ensures deterministic loading of the canonical root .env file,
session-level event loop scoping, and unified testing conventions.
"""

from pathlib import Path
from dotenv import load_dotenv
import pytest

_CANONICAL_ROOT_ENV = Path(__file__).resolve().parents[2] / ".env"
if _CANONICAL_ROOT_ENV.is_file():
    load_dotenv(_CANONICAL_ROOT_ENV)

pytestmark = pytest.mark.asyncio(loop_scope="session")
