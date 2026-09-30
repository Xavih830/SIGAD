"""Test 1: Disparo de TimeoutError exacto al superar el timeout en extracción."""

import asyncio
import time
import pytest

from app.services.resilient_pool import (
    DocumentProcessingTimeoutException,
    ResilientProcessPool,
)


def _tarea_lenta_sync(segundos: float) -> str:
    time.sleep(segundos)
    return "completado"


async def test_outbox_process_timeout_exceeded():
    """El pool resiliente debe disparar TimeoutError / DocumentProcessingTimeoutException si se excede el timeout."""
    pool_resiliente = ResilientProcessPool(max_workers=1)
    try:
        with pytest.raises(DocumentProcessingTimeoutException) as exc_info:
            await pool_resiliente.ejecutar_con_timeout(_tarea_lenta_sync, 2.0, timeout=0.2)

        assert "El procesamiento excedió 0.2s y fue abortado" in str(exc_info.value)
        assert issubclass(DocumentProcessingTimeoutException, TimeoutError)
    finally:
        pool_resiliente.terminar_forzosamente()
