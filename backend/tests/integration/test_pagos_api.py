"""Integration tests for Pagos and Installments REST API (HU-20 / UAT-20).

Validates:
1. Installment schedule querying by authorized clients and staff.
2. Strict SQL-level Anti-BOLA isolation (Cliente B gets 404 trying to view Cliente A's payments).
3. RBAC on payment registration (Admins & Agents can register, Clients receive 403).
4. Error handling for non-existent policies and installments.
"""

from datetime import date, timedelta
from decimal import Decimal
import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories.models import create_pago
from tests.factories.payloads import pago_payload
from tests.factories.scenarios import ScenarioBundle
from tests.integration.conftest import make_client

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_listar_pagos_propios_cliente(base_scenario: ScenarioBundle, db_session: AsyncSession):
    """Cliente A can list installments for their own policy."""
    poliza_a = base_scenario.poliza_a
    token_a = base_scenario.token_a

    # Create 2 installments for poliza_a
    await create_pago(
        db_session,
        poliza_id=poliza_a.id,
        numero_cuota=1,
        monto_usd=Decimal("70.00"),
        fecha_vencimiento=date.today(),
        estado="pagado",
        metodo_pago="transferencia",
        comprobante_ref="TRX-1001",
    )
    await create_pago(
        db_session,
        poliza_id=poliza_a.id,
        numero_cuota=2,
        monto_usd=Decimal("70.00"),
        fecha_vencimiento=date.today() + timedelta(days=30),
        estado="pendiente",
    )

    async with make_client(token_a) as client:
        res = await client.get(f"/api/v1/polizas/{poliza_a.id}/pagos")
        assert res.status_code == 200, res.text
        data = res.json()
        assert len(data) >= 2
        cuota_1 = next(c for c in data if c["numero_cuota"] == 1)
        assert cuota_1["estado"] == "pagado"
        assert cuota_1["monto_usd"] == 70.0
        assert cuota_1["metodo_pago"] == "transferencia"
        assert cuota_1["comprobante_ref"] == "TRX-1001"

        cuota_2 = next(c for c in data if c["numero_cuota"] == 2)
        assert cuota_2["estado"] == "pendiente"
        assert cuota_2["fecha_pago"] is None


async def test_anti_bola_cliente_no_puede_ver_pagos_ajenos(base_scenario: ScenarioBundle, db_session: AsyncSession):
    """Strict Anti-BOLA: Cliente B gets 404 trying to list payments of Cliente A's policy."""
    poliza_a = base_scenario.poliza_a
    token_b = base_scenario.token_b

    await create_pago(
        db_session,
        poliza_id=poliza_a.id,
        numero_cuota=1,
        monto_usd=Decimal("70.00"),
        fecha_vencimiento=date.today(),
        estado="pendiente",
    )

    async with make_client(token_b) as client:
        res = await client.get(f"/api/v1/polizas/{poliza_a.id}/pagos")
        assert res.status_code == 404
        assert "no encontrada" in res.json()["detail"].lower()


async def test_staff_puede_ver_pagos_cualquier_poliza(base_scenario: ScenarioBundle, db_session: AsyncSession):
    """Admin and Broker can view installment schedule for any customer's policy."""
    poliza_a = base_scenario.poliza_a
    admin_token = base_scenario.admin_token
    broker_token = base_scenario.broker_token

    await create_pago(
        db_session,
        poliza_id=poliza_a.id,
        numero_cuota=1,
        monto_usd=Decimal("70.00"),
        fecha_vencimiento=date.today(),
        estado="pendiente",
    )

    async with make_client(admin_token) as client:
        res_admin = await client.get(f"/api/v1/polizas/{poliza_a.id}/pagos")
        assert res_admin.status_code == 200
        assert len(res_admin.json()) >= 1

    async with make_client(broker_token) as client:
        res_broker = await client.get(f"/api/v1/polizas/{poliza_a.id}/pagos")
        assert res_broker.status_code == 200
        assert len(res_broker.json()) >= 1


async def test_poliza_inexistente_retorna_404(base_scenario: ScenarioBundle):
    """Querying installments for non-existent policy returns 404."""
    admin_token = base_scenario.admin_token
    fake_id = uuid.uuid4()

    async with make_client(admin_token) as client:
        res = await client.get(f"/api/v1/polizas/{fake_id}/pagos")
        assert res.status_code == 404
        assert "no encontrada" in res.json()["detail"].lower()


async def test_agente_puede_registrar_pago_cuota(base_scenario: ScenarioBundle, db_session: AsyncSession):
    """Agent/Admin can register an installment payment successfully."""
    poliza_a = base_scenario.poliza_a
    admin_token = base_scenario.admin_token

    pago = await create_pago(
        db_session,
        poliza_id=poliza_a.id,
        numero_cuota=1,
        monto_usd=Decimal("70.00"),
        fecha_vencimiento=date.today(),
        estado="pendiente",
    )

    payload = pago_payload(
        metodo_pago="transferencia",
        comprobante_ref="DEP-PICHINCHA-5544",
        fecha_pago=date.today(),
    )

    async with make_client(admin_token) as client:
        res = await client.post(f"/api/v1/polizas/{poliza_a.id}/pagos/{pago.id}/registrar", json=payload)
        assert res.status_code == 200, res.text
        data = res.json()
        assert data["id"] == str(pago.id)
        assert data["estado"] == "pagado"
        assert data["metodo_pago"] == "transferencia"
        assert data["comprobante_ref"] == "DEP-PICHINCHA-5544"
        assert data["fecha_pago"] == date.today().isoformat()


async def test_cliente_no_puede_registrar_pago_403(base_scenario: ScenarioBundle, db_session: AsyncSession):
    """Client role is forbidden from registering payments directly."""
    poliza_a = base_scenario.poliza_a
    token_a = base_scenario.token_a

    pago = await create_pago(
        db_session,
        poliza_id=poliza_a.id,
        numero_cuota=1,
        monto_usd=Decimal("70.00"),
        fecha_vencimiento=date.today(),
        estado="pendiente",
    )

    payload = pago_payload(
        metodo_pago="tarjeta",
        comprobante_ref="AUTH-7788",
    )

    async with make_client(token_a) as client:
        res = await client.post(f"/api/v1/polizas/{poliza_a.id}/pagos/{pago.id}/registrar", json=payload)
        assert res.status_code == 403


async def test_registrar_pago_cuota_inexistente_404(base_scenario: ScenarioBundle):
    """Registering payment for non-existent installment returns 404."""
    poliza_a = base_scenario.poliza_a
    admin_token = base_scenario.admin_token
    fake_pago_id = uuid.uuid4()

    payload = pago_payload(
        metodo_pago="debito_bancario",
        comprobante_ref="REF-UNKNOWN",
    )

    async with make_client(admin_token) as client:
        res = await client.post(f"/api/v1/polizas/{poliza_a.id}/pagos/{fake_pago_id}/registrar", json=payload)
        assert res.status_code == 404
        assert "no encontrada" in res.json()["detail"].lower()
