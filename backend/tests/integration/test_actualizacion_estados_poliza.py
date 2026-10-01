"""Integration test for policy state updates and PostgreSQL audit triggers.

Obligatory Test #15 / #21 (Section 21 of poryecto.md).
Verifies:
  1. Policy state transition via PATCH /api/v1/polizas/{id}/estado updates the record.
  2. The PostgreSQL AFTER UPDATE trigger (`trg_audit_polizas`) automatically logs the change
     into the `historial_cambios` audit table:
       - entidad: 'polizas'
       - entidad_id: poliza.id
       - campo: 'estado'
       - valor_anterior: 'activa'
       - valor_nuevo: 'cancelada'
"""

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

    # 1. Realizar actualización de estado a CANCELADA via API
    async with make_client(admin_token) as client:
        response = await client.patch(
            f"/api/v1/polizas/{poliza_a.id}/estado",
            json={"estado": "cancelada"},
        )
        assert response.status_code == 200, response.text
        updated = response.json()
        assert updated["estado"] == "cancelada"

    # 2. Consultar la tabla historial_cambios para comprobar el trigger de PostgreSQL
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
