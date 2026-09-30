"""Outbox consumer — processes OCR extraction tasks using transactional skip-locked leases."""

import asyncio
from datetime import datetime, timezone
import logging
import uuid

from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import async_session_factory
from app.models.documento import Documento, EstadoExtraccionEnum
from app.models.resultado_extraccion import ResultadoExtraccion
from app.services.extraccion_service import extraer_documento_sync
from app.services.resilient_pool import DocumentProcessingTimeoutException, resilient_pool

logger = logging.getLogger(__name__)


async def adquirir_siguiente_documento(db: AsyncSession) -> tuple[uuid.UUID, str, uuid.UUID] | None:
    """Acquires a single pending document using SELECT FOR UPDATE SKIP LOCKED with lease token fencing.
    
    Returns:
        tuple of (documento_id, ruta_archivo, lease_token) or None if no pending documents.
    """
    # 1. Atomic acquisition
    stmt = text(
        """
        SELECT id, ruta_archivo
        FROM documentos
        WHERE estado_extraccion = 'pendiente'
        ORDER BY created_at ASC
        FOR UPDATE SKIP LOCKED
        LIMIT 1;
        """
    )
    result = await db.execute(stmt)
    row = result.first()
    if not row:
        return None

    doc_id, ruta_archivo = row[0], row[1]
    lease_token = uuid.uuid4()

    # 2. Lock lease token and transition to procesando
    update_stmt = text(
        """
        UPDATE documentos
        SET estado_extraccion = 'procesando',
            lease_token = :lease_token,
            updated_at = NOW()
        WHERE id = :id AND estado_extraccion = 'pendiente';
        """
    )
    await db.execute(update_stmt, {"lease_token": lease_token, "id": doc_id})
    await db.commit()

    return doc_id, ruta_archivo, lease_token


async def procesar_documento_adquirido(
    db: AsyncSession,
    doc_id: uuid.UUID,
    ruta_archivo: str,
    lease_token: uuid.UUID,
    timeout_seconds: float = 120.0,
) -> bool:
    """Executes extraction in resilient pool and safely commits results with fencing token check."""
    try:
        resultado_dict = await resilient_pool.ejecutar_con_timeout(
            extraer_documento_sync,
            ruta_archivo,
            timeout=timeout_seconds,
        )

        # Confirm lease is still valid before writing
        resultado = ResultadoExtraccion(
            documento_id=doc_id,
            texto_completo=resultado_dict["texto_completo"],
            metodo=resultado_dict["metodo"],
            confianza=resultado_dict["confianza"],
            campos_extraidos=resultado_dict["campos_extraidos"],
        )
        db.add(resultado)

        # Fenced update
        update_stmt = text(
            """
            UPDATE documentos
            SET estado_extraccion = :nuevo_estado,
                lease_token = NULL,
                error_motivo = NULL,
                updated_at = NOW()
            WHERE id = :id AND lease_token = :lease_token;
            """
        )
        res = await db.execute(
            update_stmt,
            {
                "nuevo_estado": EstadoExtraccionEnum.COMPLETADO.value,
                "id": doc_id,
                "lease_token": lease_token,
            },
        )
        if res.rowcount == 0:
            logger.warning("Fencing lease lost for document %s, aborted commit", doc_id)
            await db.rollback()
            return False

        await db.commit()
        return True

    except DocumentProcessingTimeoutException as e:
        logger.error("Timeout processing doc %s: %s", doc_id, e)
        update_stmt = text(
            """
            UPDATE documentos
            SET estado_extraccion = :nuevo_estado,
                lease_token = NULL,
                error_motivo = :error_motivo,
                updated_at = NOW()
            WHERE id = :id AND lease_token = :lease_token;
            """
        )
        await db.execute(
            update_stmt,
            {
                "nuevo_estado": EstadoExtraccionEnum.ERROR.value,
                "error_motivo": str(e),
                "id": doc_id,
                "lease_token": lease_token,
            },
        )
        await db.commit()
        return False

    except Exception as e:
        logger.exception("Unexpected error processing doc %s: %s", doc_id, e)
        update_stmt = text(
            """
            UPDATE documentos
            SET estado_extraccion = :nuevo_estado,
                lease_token = NULL,
                error_motivo = :error_motivo,
                updated_at = NOW()
            WHERE id = :id AND lease_token = :lease_token;
            """
        )
        await db.execute(
            update_stmt,
            {
                "nuevo_estado": EstadoExtraccionEnum.ERROR.value,
                "error_motivo": str(e),
                "id": doc_id,
                "lease_token": lease_token,
            },
        )
        await db.commit()
        return False


async def procesar_un_ciclo_outbox(
    db: AsyncSession | None = None,
    timeout_seconds: float = 120.0,
) -> bool:
    """Process a single pending job from the outbox. Returns True if a job was processed."""
    if db is not None:
        adquirido = await adquirir_siguiente_documento(db)
        if not adquirido:
            return False
        doc_id, ruta, lease = adquirido
        return await procesar_documento_adquirido(db, doc_id, ruta, lease, timeout_seconds=timeout_seconds)

    async with async_session_factory() as session:
        adquirido = await adquirir_siguiente_documento(session)
        if not adquirido:
            return False
        doc_id, ruta, lease = adquirido
        return await procesar_documento_adquirido(session, doc_id, ruta, lease, timeout_seconds=timeout_seconds)


async def loop_consumidor_outbox(intervalo_segundos: float = 2.0) -> None:
    """Continuous background loop for the outbox consumer worker."""
    logger.info("Outbox consumer worker started.")
    while True:
        try:
            hubo_trabajo = await procesar_un_ciclo_outbox()
            if not hubo_trabajo:
                await asyncio.sleep(intervalo_segundos)
        except asyncio.CancelledError:
            logger.info("Outbox consumer received cancel signal.")
            break
        except Exception as e:
            logger.exception("Error in outbox consumer loop: %s", e)
            await asyncio.sleep(intervalo_segundos)
