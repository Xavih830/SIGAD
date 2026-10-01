"""Integration test for historical deductible migration (SC-2026-001, Section 12.4).

Obligatory Test #14 / #36 (Section 21 of poryecto.md).
Verifies:
  1. Legacy policies without deductibles receive the standard default deductible:
     - tipo_siniestro: 'general'
     - porcentaje_valor: 10.0%
     - monto_minimo_usd: $200.00
  2. Policies that already possess deductibles are not duplicated (idempotence).
"""

from datetime import date, timedelta
from decimal import Decimal
import uuid

import pytest
from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.poliza_evaluator import EstadoPoliza
from app.models.deducible import Deducible, TipoSiniestroEnum
from app.models.poliza import Poliza
from tests.factories import create_poliza
from tests.factories.scenarios import ScenarioBundle

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_migracion_deducibles_historicos_idempotente(db_session: AsyncSession, base_scenario: ScenarioBundle):
    """Verify Section 12.4 migration SQL successfully backfills legacy policies."""
    cliente_a = base_scenario.cliente_a
    vehiculo_a = base_scenario.vehiculo_a

    # 1. Crear una póliza "histórica" sin ningún deducible asociado
    poliza_historica = await create_poliza(
        db_session,
        cliente_id=cliente_a.id,
        vehiculo_id=vehiculo_a.id,
        numero_poliza=f"POL-HIST-{uuid.uuid4().hex[:6].upper()}",
        fecha_inicio=date.today() - timedelta(days=200),
        fecha_fin=date.today() + timedelta(days=165),
        estado=EstadoPoliza.ACTIVA,
        valor_asegurado=Decimal("20000.00"),
        prima_mensual=Decimal("50.00"),
        kilometraje_emision=12000,
        with_default_deductible=False,
    )
    await db_session.commit()

    # Verificar que no tiene deducibles
    deducibles_prev = (
        await db_session.execute(
            select(Deducible).where(Deducible.poliza_id == poliza_historica.id)
        )
    ).scalars().all()
    assert len(deducibles_prev) == 0, "La póliza histórica inicial no debe tener deducibles."

    # 2. Ejecutar la sentencia SQL de migración histórica de la Sección 12.4
    sql_migracion = text(
        """
        INSERT INTO deducibles (id, poliza_id, tipo_siniestro, porcentaje_valor, monto_minimo_usd, created_at)
        SELECT 
            gen_random_uuid(), 
            id, 
            'general', 
            10.0, 
            200.0, 
            NOW()
        FROM polizas
        WHERE NOT EXISTS (
            SELECT 1 FROM deducibles WHERE deducibles.poliza_id = polizas.id
        );
        """
    )
    await db_session.execute(sql_migracion)
    await db_session.commit()

    # 3. Comprobar que se generó exactamente el deducible por defecto
    deducibles_post = (
        await db_session.execute(
            select(Deducible).where(Deducible.poliza_id == poliza_historica.id)
        )
    ).scalars().all()

    assert len(deducibles_post) == 1, "Debe haberse creado exactamente 1 deducible general."
    d = deducibles_post[0]
    assert d.tipo_siniestro == TipoSiniestroEnum.GENERAL
    assert d.porcentaje_valor == Decimal("10.00")
    assert d.monto_minimo_usd == Decimal("200.00")

    # 4. Probar idempotencia: volver a ejecutar la sentencia no debe insertar duplicados
    await db_session.execute(sql_migracion)
    await db_session.commit()

    deducibles_idempotencia = (
        await db_session.execute(
            select(Deducible).where(Deducible.poliza_id == poliza_historica.id)
        )
    ).scalars().all()

    assert len(deducibles_idempotencia) == 1, "La migración debe ser idempotente; no generar duplicados."
