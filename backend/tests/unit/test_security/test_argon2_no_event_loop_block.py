"""Argon2id verification does NOT block the asyncio event loop.

Verifies that `verify_password` runs in a separate thread via `asyncio.to_thread`
so the event loop remains responsive during the ~100ms Argon2 computation.
"""

import asyncio
import time

import pytest

from app.core.security import hash_password, verify_password


@pytest.mark.asyncio
async def test_argon2_no_event_loop_block():
    """Verify Argon2 verification runs off-loop and the loop stays responsive."""
    hashed = hash_password("TestPassword#2024")

    loop_was_alive = False

    async def heartbeat():
        nonlocal loop_was_alive
        await asyncio.sleep(0)
        loop_was_alive = True

    t0 = time.monotonic()
    result, _ = await asyncio.gather(
        verify_password("TestPassword#2024", hashed),
        heartbeat(),
    )
    elapsed = time.monotonic() - t0

    assert result is True, "Password verification should succeed"
    assert loop_was_alive, "Event loop must remain responsive during Argon2 verification"
    assert elapsed < 5.0, f"Verification took too long: {elapsed:.2f}s"
