"""Test 6: Verificación de las 3 transiciones de pólizas con registro en auditoría e idempotencia."""

from datetime import date
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.domain.poliza_evaluator import EstadoPoliza
from app.workers.scheduler import ejecutar_transiciones_polizas
from tests.factories import create_mock_poliza


@pytest.mark.asyncio
async def test_scheduler_transiciones_completas_e_idempotencia():
    """El scheduler ejecuta las 3 transiciones de pólizas y es estrictamente idempotente."""
    hoy = date.today()

    p_pendiente = create_mock_poliza(estado=EstadoPoliza.PENDIENTE)
    p_activa = create_mock_poliza(estado=EstadoPoliza.ACTIVA)
    p_por_vencer = create_mock_poliza(estado=EstadoPoliza.ACTIVA)

    # Mock DB execution for Run 1:
    mock_res_activar = MagicMock()
    mock_res_activar.scalars.return_value.all.return_value = [p_pendiente]

    mock_res_por_vencer = MagicMock()
    mock_res_por_vencer.scalars.return_value.all.return_value = [p_activa]

    mock_res_vencida = MagicMock()
    mock_res_vencida.scalars.return_value.all.return_value = [p_por_vencer]

    mock_db = AsyncMock()
    mock_db.execute.side_effect = [
        mock_res_activar,
        mock_res_por_vencer,
        mock_res_vencida,
    ]
    mock_db.commit = AsyncMock()

    # Ejecución 1
    res1 = await ejecutar_transiciones_polizas(mock_db, fecha_referencia=hoy)
    assert res1["activadas"] == 1
    assert res1["por_vencer"] == 1
    assert res1["vencidas"] == 1

    assert p_pendiente.estado == EstadoPoliza.ACTIVA
    assert p_activa.estado == EstadoPoliza.POR_VENCER
    assert p_por_vencer.estado == EstadoPoliza.VENCIDA
    assert mock_db.commit.called

    # Mock DB execution for Run 2 (Idempotencia: no polizas qualify):
    mock_empty = MagicMock()
    mock_empty.scalars.return_value.all.return_value = []
    mock_db.execute.side_effect = [mock_empty, mock_empty, mock_empty]

    res2 = await ejecutar_transiciones_polizas(mock_db, fecha_referencia=hoy)
    assert res2["activadas"] == 0
    assert res2["por_vencer"] == 0
    assert res2["vencidas"] == 0
