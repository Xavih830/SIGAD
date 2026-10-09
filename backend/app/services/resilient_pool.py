"""Resilient process pool with spawn context and hard SIGKILL termination."""

import asyncio
from concurrent.futures import ProcessPoolExecutor
import multiprocessing as mp
from typing import Any, Callable

from app.core.constants import OCR_PROCESS_TIMEOUT_SECONDS


class DocumentProcessingTimeoutException(TimeoutError):
    """Raised when document extraction exceeds the operational timeout."""
    pass


def terminar_pool_forzosamente(executor: ProcessPoolExecutor) -> None:
    """Envía señal SIGKILL real inmediata a cada subproceso activo del pool y cancela futuros."""
    if hasattr(executor, "_processes"):
        for pid, proc in list(executor._processes.items()):
            try:
                if proc.is_alive():
                    proc.kill()  # SIGKILL inmediato en Linux
            except (ProcessLookupError, AttributeError):
                pass
    executor.shutdown(wait=False, cancel_futures=True)


def recrear_pool(max_workers: int = 1) -> ProcessPoolExecutor:
    """Crea una nueva instancia de ProcessPoolExecutor aislada usando spawn."""
    ctx = mp.get_context("spawn")
    return ProcessPoolExecutor(max_workers=max_workers, mp_context=ctx)


class ResilientProcessPool:
    """Manages an isolated worker pool with guaranteed hard SIGKILL cleanup on timeout."""

    def __init__(self, max_workers: int = 1) -> None:
        self.max_workers = max_workers
        self._ctx = mp.get_context("spawn")
        self._pool: ProcessPoolExecutor = ProcessPoolExecutor(
            max_workers=self.max_workers,
            mp_context=self._ctx,
        )

    @property
    def pool(self) -> ProcessPoolExecutor:
        return self._pool

    def terminar_forzosamente(self) -> None:
        """Kills any stuck sub-process via SIGKILL and terminates the pool."""
        terminar_pool_forzosamente(self._pool)

    def recrear(self) -> ProcessPoolExecutor:
        """Recreates an empty, clean pool ready for next jobs."""
        self.terminar_forzosamente()
        self._pool = ProcessPoolExecutor(
            max_workers=self.max_workers,
            mp_context=self._ctx,
        )
        return self._pool

    async def ejecutar_con_timeout(
        self,
        func: Callable[..., Any],
        *args: Any,
        timeout: float = float(OCR_PROCESS_TIMEOUT_SECONDS),
    ) -> Any:
        """Executes a CPU/IO-bound sync function in the process pool with strict timeout.
        
        If timeout is exceeded, the worker is immediately killed with SIGKILL,
        the pool is recreated, and DocumentProcessingTimeoutException is raised.
        """
        loop = asyncio.get_running_loop()
        try:
            return await asyncio.wait_for(
                loop.run_in_executor(self._pool, func, *args),
                timeout=timeout,
            )
        except asyncio.TimeoutError:
            self.recrear()
            raise DocumentProcessingTimeoutException(
                f"El procesamiento excedió {timeout}s y fue abortado"
            )


resilient_pool = ResilientProcessPool(max_workers=1)
