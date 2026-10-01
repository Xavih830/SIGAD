"""Integration test for inmutable emission mileage snapshot (SC-2026-001 & Sec 3.2).

Obligatory Test #12 (Section 21 of poryecto.md).
Verifies:
  1. The `vehiculos` model and table has NO mutable `kilometraje` column.
  2. Mileage readings are stored in `inspecciones`.
  3. When a policy is issued, `kilometraje_emision` is recorded inmutably in `polizas`.
  4. Adding new inspections with higher mileage does NOT mutate `polizas.kilometraje_emision`.
"""

from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import uuid

import pytest
from sqlalchemy import inspect, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.poliza_evaluator import EstadoPoliza
from app.models.poliza import Poliza
from app.models.vehiculo import Vehiculo
from tests.factories import create_inspeccion, poliza_payload
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_vehiculo_no_tiene_columna_kilometraje():
    """Verify vehiculos entity does not contain a mutable kilometraje attribute/column."""
    mapper = inspect(Vehiculo)
    column_names = [col.key for col in mapper.columns]
    assert "kilometraje" not in column_names, (
        "Invariante violada: la tabla 'vehiculos' no debe almacenar kilometraje mutable; "
        "debe residir en inspecciones y capturarse como snapshot en polizas.kilometraje_emision."
    )


async def test_kilometraje_snapshot_inmutable(db_session: AsyncSession, base_scenario: ScenarioBundle):
    """Verify that issuing a policy freezes kilometraje_emision independently of future inspections."""
    cliente_a = base_scenario.cliente_a
    vehiculo_a = base_scenario.vehiculo_a
    admin_token = base_scenario.admin_token

    # 1. Crear una inspección previa con 25,000 km
    inspeccion_1 = await create_inspeccion(
        db_session,
        vehiculo_id=vehiculo_a.id,
        kilometraje=25000,
        observaciones="Inspección de emisión",
    )
    await db_session.commit()

    # 2. Emitir póliza via API con snapshot de 25,000 km
    poliza_num = f"POL-SNAP-{uuid.uuid4().hex[:6].upper()}"
    payload = poliza_payload(
        cliente_a.id,
        vehiculo_a.id,
        inspeccion_id=inspeccion_1.id,
        numero_poliza=poliza_num,
        fecha_inicio=date.today() - timedelta(days=5),
        fecha_fin=date.today() + timedelta(days=360),
        valor_asegurado=22000.00,
        prima_mensual=65.00,
        kilometraje_emision=25000,
    )
    async with make_client(admin_token) as client:
        response = await client.post("/api/v1/polizas", json=payload)
        assert response.status_code == 201, response.text
        created_data = response.json()
        poliza_id = created_data["id"]
        assert created_data["kilometraje_emision"] == 25000

    # 3. Registrar una nueva inspección 6 meses después con 38,000 km
    inspeccion_2 = await create_inspeccion(
        db_session,
        vehiculo_id=vehiculo_a.id,
        kilometraje=38000,
        observaciones="Inspección semestral",
    )
    await db_session.commit()

    # 4. Verificar en BD que kilometraje_emision de la póliza sigue siendo exactamente 25,000 km
    stmt = select(Poliza).where(Poliza.id == uuid.UUID(poliza_id))
    poliza_db = (await db_session.execute(stmt)).scalar_one()

    assert poliza_db.kilometraje_emision == 25000, (
        f"El kilometraje de emisión cambió a {poliza_db.kilometraje_emision}; debe ser inmutable."
    )
