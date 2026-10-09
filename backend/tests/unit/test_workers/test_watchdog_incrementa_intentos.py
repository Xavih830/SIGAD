"""Incremento atómico de intentos y transición a error_permanente al 3er fallo."""

from unittest.mock import AsyncMock, MagicMock
import pytest

from app.workers.watchdog import ejecutar_watchdog_rescate


@pytest.mark.asyncio
async def test_watchdog_atomic_increment_to_permanent_error():
    """Verifica que el SQL del watchdog enforce la condición atómica hacia 'error_permanente' al 3er intento."""
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.rowcount = 1
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()

    afectados = await ejecutar_watchdog_rescate(mock_db, stale_minutes=5)

    assert afectados == 1
    sql_text = mock_db.execute.call_args[0][0].text

    assert "WHEN intentos + 1 >= 3 THEN 'error_permanente'" in sql_text
    assert "WHEN intentos + 1 >= 3 THEN 'max_intentos_alcanzados_watchdog'" in sql_text
    assert "intentos = intentos + 1" in sql_text
    assert "lease_token = NULL" in sql_text
