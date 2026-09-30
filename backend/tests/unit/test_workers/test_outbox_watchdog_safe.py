"""Test 4: Watchdog rescata documentos abandonados restableciendo el estado a pendiente."""

from unittest.mock import AsyncMock, MagicMock
import pytest

from app.workers.watchdog import ejecutar_watchdog_rescate


@pytest.mark.asyncio
async def test_outbox_watchdog_rescues_abandoned_document():
    """El watchdog rescata documentos colgados en procesando y restablece estado a pendiente."""
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.rowcount = 2  # Simula 2 documentos rescatados
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()

    rescatados = await ejecutar_watchdog_rescate(mock_db, stale_minutes=5)

    assert rescatados == 2
    assert mock_db.execute.called
    assert mock_db.commit.called

    # Verificar que la consulta SQL contiene las cláusulas requeridas
    call_args = mock_db.execute.call_args
    sql_text = call_args[0][0].text
    params = call_args[0][1]

    assert "UPDATE documentos" in sql_text
    assert "estado_extraccion = CASE" in sql_text
    assert "ELSE 'pendiente'" in sql_text
    assert "intentos = intentos + 1" in sql_text
    assert "lease_token = NULL" in sql_text
    assert "WHERE estado_extraccion = 'procesando'" in sql_text
    assert params == {"stale_minutes": "5"}
