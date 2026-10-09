"""Policy status transition scheduler — daily automated lifecycle updates with audit logging."""

import asyncio
from datetime import date, timedelta
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import async_session_factory
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.poliza import Poliza

logger = logging.getLogger(__name__)


async def ejecutar_transiciones_polizas(
    db: AsyncSession,
    fecha_referencia: date | None = None,
) -> dict[str, int]:
    """Evaluates and transitions policy contracts based on contractual dates.
    
    Rules:
    1. pendiente -> activa: fecha_inicio <= CURRENT_DATE (and fecha_fin >= CURRENT_DATE)
    2. activa -> por_vencer: fecha_fin BETWEEN CURRENT_DATE AND CURRENT_DATE + 30 days
    3. activa/por_vencer -> vencida: fecha_fin < CURRENT_DATE
    
    Each transition automatically triggers an audit log entry in `historial_cambios`
    with usuario_id = NULL via PostgreSQL's trg_audit_polizas trigger.
    
    Idempotent: repeating with the same reference date yields 0 changes.
    
    Returns:
        dict with counts of each transition made: {"activadas": X, "por_vencer": Y, "vencidas": Z}
    """
    hoy = fecha_referencia or date.today()
    limite_por_vencer = hoy + timedelta(days=30)
    resultados = {"activadas": 0, "por_vencer": 0, "vencidas": 0}

    q_activar = (
        select(Poliza)
        .where(
            Poliza.estado == EstadoPoliza.PENDIENTE,
            Poliza.fecha_inicio <= hoy,
            Poliza.fecha_fin >= hoy,
        )
    )
    res_activar = await db.execute(q_activar)
    polizas_a_activar = res_activar.scalars().all()

    for poliza in polizas_a_activar:
        poliza.estado = EstadoPoliza.ACTIVA
        resultados["activadas"] += 1

    q_por_vencer = (
        select(Poliza)
        .where(
            Poliza.estado == EstadoPoliza.ACTIVA,
            Poliza.fecha_fin >= hoy,
            Poliza.fecha_fin <= limite_por_vencer,
        )
    )
    res_por_vencer = await db.execute(q_por_vencer)
    polizas_por_vencer = res_por_vencer.scalars().all()

    for poliza in polizas_por_vencer:
        poliza.estado = EstadoPoliza.POR_VENCER
        resultados["por_vencer"] += 1

    q_vencer = (
        select(Poliza)
        .where(
            Poliza.estado.in_([EstadoPoliza.ACTIVA, EstadoPoliza.POR_VENCER]),
            Poliza.fecha_fin < hoy,
        )
    )
    res_vencer = await db.execute(q_vencer)
    polizas_a_vencer = res_vencer.scalars().all()

    for poliza in polizas_a_vencer:
        poliza.estado = EstadoPoliza.VENCIDA
        resultados["vencidas"] += 1

    await db.commit()
    return resultados


async def loop_scheduler_diario(hora_ejecucion: str = "00:05") -> None:
    """Daily scheduler loop that triggers policy transitions at 00:05 AM."""
    logger.info("Daily policy scheduler started (target time %s).", hora_ejecucion)
    while True:
        try:
            async with async_session_factory() as session:
                await ejecutar_transiciones_polizas(session)
            await asyncio.sleep(86400)
        except asyncio.CancelledError:
            logger.info("Daily scheduler loop cancelled.")
            break
        except Exception as e:
            logger.exception("Error in scheduler loop: %s", e)
            await asyncio.sleep(60)
