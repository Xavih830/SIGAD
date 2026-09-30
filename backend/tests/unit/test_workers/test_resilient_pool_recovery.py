"""Test 3: Recreación y disponibilidad inmediata del pool tras terminar un proceso colgado."""

import time
import pytest

from app.services.resilient_pool import (
    DocumentProcessingTimeoutException,
    ResilientProcessPool,
)


def _tarea_colgada() -> None:
    time.sleep(5.0)


def _tarea_saludable(a: int, b: int) -> int:
    return a + b


async def test_resilient_pool_recovery_after_timeout():
    """Tras abortar un proceso colgado por timeout, el pool se recrea y procesa nuevos trabajos inmediatamente."""
    pool = ResilientProcessPool(max_workers=1)
    try:
        # 1. Tarea que cuelga y provoca timeout
        with pytest.raises(DocumentProcessingTimeoutException):
            await pool.ejecutar_con_timeout(_tarea_colgada, timeout=0.2)

        # 2. Inmediatamente después, el pool debe estar disponible para trabajo normal
        resultado = await pool.ejecutar_con_timeout(_tarea_saludable, 17, 25, timeout=2.0)
        assert resultado == 42, f"Se esperaba 42 pero se obtuvo {resultado}"

        # 3. Una tercera tarea para verificar estabilidad continua
        resultado_2 = await pool.ejecutar_con_timeout(_tarea_saludable, 100, 200, timeout=2.0)
        assert resultado_2 == 300
    finally:
        pool.terminar_forzosamente()
