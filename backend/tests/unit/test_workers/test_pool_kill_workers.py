"""Subproceso de extracción colgado es aniquilado con proc.kill() (SIGKILL)."""

import asyncio
from concurrent.futures import ProcessPoolExecutor
import multiprocessing as mp
import os
import time
import pytest

from app.services.resilient_pool import terminar_pool_forzosamente


def _bucle_infinito_sync() -> None:
    while True:
        time.sleep(0.1)


async def test_pool_kill_workers_terminates_subprocess():
    """Verifica que terminar_pool_forzosamente envía SIGKILL a los subprocesos vivos."""
    ctx = mp.get_context("spawn")
    executor = ProcessPoolExecutor(max_workers=1, mp_context=ctx)
    loop = asyncio.get_running_loop()

    future = loop.run_in_executor(executor, _bucle_infinito_sync)

    for _ in range(50):
        if hasattr(executor, "_processes") and len(executor._processes) > 0:
            break
        await asyncio.sleep(0.05)

    assert len(executor._processes) > 0, "El subproceso debió iniciarse"
    proc = next(iter(executor._processes.values()))
    pid = proc.pid
    assert proc.is_alive(), "El subproceso debe estar corriendo activamente"

    terminar_pool_forzosamente(executor)

    await asyncio.sleep(0.1)
    assert not proc.is_alive(), f"El subproceso con PID {pid} debió ser eliminado con SIGKILL"

    is_still_running = True
    try:
        os.kill(pid, 0)
    except (ProcessLookupError, OSError):
        is_still_running = False

    assert not is_still_running, "El PID no debe existir en el sistema operativo"
