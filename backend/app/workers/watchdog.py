"""Watchdog worker — rescues orphaned document processing tasks with atomic retry increments."""

import asyncio
import logging
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import async_session_factory

logger = logging.getLogger(__name__)


async def ejecutar_watchdog_rescate(
    db: AsyncSession,
    stale_minutes: int = 5,
) -> int:
    """Executes atomic SQL rescue of hanging documents.
    
    If intentos + 1 >= 3:
        transitions to 'error_permanente' with error_motivo = 'max_intentos_alcanzados_watchdog'
    Else:
        transitions back to 'pendiente' to allow retry.
    
    Returns:
        Number of documents updated.
    """
    stmt = text(
        """
        UPDATE documentos
        SET estado_extraccion = CASE 
                WHEN intentos + 1 >= 3 THEN 'error_permanente' 
                ELSE 'pendiente' 
            END,
            intentos = intentos + 1,
            lease_token = NULL,
            error_motivo = CASE 
                WHEN intentos + 1 >= 3 THEN 'max_intentos_alcanzados_watchdog' 
                ELSE error_motivo 
            END,
            updated_at = NOW()
        WHERE estado_extraccion = 'procesando'
          AND updated_at < NOW() - (:stale_minutes || ' minutes')::INTERVAL;
        """
    )
    result = await db.execute(stmt, {"stale_minutes": str(stale_minutes)})
    await db.commit()
    filas_afectadas = result.rowcount
    if filas_afectadas > 0:
        logger.warning("Watchdog rescued %d abandoned documents", filas_afectadas)
    return filas_afectadas


async def loop_watchdog(intervalo_segundos: float = 60.0, stale_minutes: int = 5) -> None:
    """Continuous periodic loop for watchdog monitoring."""
    logger.info("Watchdog loop started.")
    while True:
        try:
            async with async_session_factory() as session:
                await ejecutar_watchdog_rescate(session, stale_minutes=stale_minutes)
            await asyncio.sleep(intervalo_segundos)
        except asyncio.CancelledError:
            logger.info("Watchdog loop received cancel signal.")
            break
        except Exception as e:
            logger.exception("Error in watchdog loop: %s", e)
            await asyncio.sleep(intervalo_segundos)
