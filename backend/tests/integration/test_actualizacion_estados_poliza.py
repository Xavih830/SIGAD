"""Prueba de integración para actualización de estados de póliza y triggers de auditoría."""

import uuid

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.poliza_evaluator import EstadoPoliza
from app.models.historial_cambio import HistorialCambio
from app.models.poliza import Poliza
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_actualizacion_estado_dispara_trigger_auditoria(db_session: AsyncSession, base_scenario: ScenarioBundle):
    """Verify state transition and PostgreSQL trigger audit logging."""
    admin_token = base_scenario.admin_token
    poliza_a = base_scenario.poliza_a

    assert poliza_a.estado == EstadoPoliza.ACTIVA

    async with make_client(admin_token) as client:
        response = await client.patch(
            f"/api/v1/polizas/{poliza_a.id}/estado",
            json={"estado": "cancelada"},
        )
        assert response.status_code == 200, response.text
        updated = response.json()
        assert updated["estado"] == "cancelada"

    stmt = (
        select(HistorialCambio)
        .where(
            HistorialCambio.entidad == "polizas",
            HistorialCambio.entidad_id == poliza_a.id,
            HistorialCambio.campo == "estado",
        )
        .order_by(HistorialCambio.fecha.desc())
    )
    resultado = await db_session.execute(stmt)
    registro_auditoria = resultado.scalar_one_or_none()

    assert registro_auditoria is not None, (
        "El trigger de PostgreSQL 'trg_audit_polizas' no insertó el registro en historial_cambios."
    )
    assert registro_auditoria.valor_anterior == "activa"
    assert registro_auditoria.valor_nuevo == "cancelada"
