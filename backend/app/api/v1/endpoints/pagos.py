"""Endpoints REST para consulta y liquidación de cuotas de pólizas."""

from datetime import date
from typing import Any
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.pago import Pago
from app.models.poliza import Poliza
from app.models.usuario import RolEnum, Usuario
from app.schemas.pago import PagoResponse, RegistrarPagoRequest

router = APIRouter(prefix="/polizas/{poliza_id}/pagos", tags=["Pagos"])


@router.get("", response_model=list[PagoResponse])
async def listar_pagos_poliza(
    poliza_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Any:
    """Listar cronograma de pagos y cuotas de una póliza."""
    stmt = select(Poliza).options(selectinload(Poliza.cliente)).where(Poliza.id == poliza_id)
    res = await db.execute(stmt)
    poliza = res.scalar_one_or_none()

    if not poliza:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Póliza no encontrada.")

    if current_user.rol == RolEnum.CLIENTE:
        if not poliza.cliente or poliza.cliente.usuario_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Póliza no encontrada.")

    stmt_pagos = select(Pago).where(Pago.poliza_id == poliza_id).order_by(Pago.numero_cuota)
    res_pagos = await db.execute(stmt_pagos)
    return res_pagos.scalars().all()


@router.post("/{pago_id}/registrar", response_model=PagoResponse)
async def registrar_pago_cuota(
    poliza_id: uuid.UUID,
    pago_id: uuid.UUID,
    payload: RegistrarPagoRequest,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Any:
    """Registrar el pago de una cuota de póliza."""
    if current_user.rol not in [RolEnum.ADMIN, RolEnum.AGENTE]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No autorizado para registrar pagos.")

    stmt = select(Pago).where(Pago.id == pago_id, Pago.poliza_id == poliza_id)
    res = await db.execute(stmt)
    pago = res.scalar_one_or_none()

    if not pago:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cuota no encontrada.")

    pago.estado = "pagado"
    pago.fecha_pago = payload.fecha_pago or date.today()
    pago.metodo_pago = payload.metodo_pago
    pago.comprobante_ref = payload.comprobante_ref

    await db.commit()
    await db.refresh(pago)
    return pago
