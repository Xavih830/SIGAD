"""Poliza repository protocol and SQLAlchemy implementation."""

import uuid
from collections.abc import Sequence
from typing import Protocol, runtime_checkable

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.constants import DEFAULT_PAGE_LIMIT
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.cliente import Cliente
from app.models.deducible import Deducible
from app.models.esquema_poliza import EsquemaPoliza
from app.models.historial_cambio import HistorialCambio
from app.models.poliza import Poliza
from app.models.vehiculo import Vehiculo
from app.repositories.base import BaseRepository


@runtime_checkable
class PolizaRepositoryProtocol(Protocol):
    """Puerto de persistencia para pólizas, historial y entidades auxiliares."""

    async def get(
        self,
        poliza_id: uuid.UUID,
        *,
        owner_usuario_id: uuid.UUID | None = None,
    ) -> Poliza | None: ...

    async def list(
        self,
        *,
        estado: EstadoPoliza | None = None,
        owner_usuario_id: uuid.UUID | None = None,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> Sequence[Poliza]: ...

    async def add(self, poliza: Poliza) -> Poliza: ...

    async def update(self, poliza: Poliza) -> Poliza: ...

    async def historial(
        self,
        poliza_id: uuid.UUID,
        *,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> tuple[Sequence[HistorialCambio], int]: ...

    async def get_cliente(self, cliente_id: uuid.UUID) -> Cliente | None: ...

    async def get_vehiculo(self, vehiculo_id: uuid.UUID) -> Vehiculo | None: ...

    async def get_by_numero(self, numero_poliza: str) -> Poliza | None: ...

    async def get_esquema(self, esquema_id: uuid.UUID) -> EsquemaPoliza | None: ...

    async def list_deducibles(self, poliza_id: uuid.UUID) -> Sequence[Deducible]: ...

    async def add_extra(self, obj: object) -> None: ...

    async def flush(self) -> None: ...

    async def commit(self) -> None: ...


class PolizaRepository(BaseRepository[Poliza]):
    """Implementación SQLAlchemy del repositorio de pólizas."""

    model = Poliza

    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db)

    async def get(  # type: ignore[override]
        self,
        poliza_id: uuid.UUID,
        *,
        owner_usuario_id: uuid.UUID | None = None,
    ) -> Poliza | None:
        stmt = (
            select(Poliza)
            .options(
                selectinload(Poliza.vehiculo),
                selectinload(Poliza.deducibles),
                selectinload(Poliza.coberturas),
            )
            .where(Poliza.id == poliza_id)
        )
        if owner_usuario_id is not None:
            stmt = stmt.join(Cliente, Poliza.cliente_id == Cliente.id).where(
                Cliente.usuario_id == owner_usuario_id
            )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def list(  # type: ignore[override]
        self,
        *,
        estado: EstadoPoliza | None = None,
        owner_usuario_id: uuid.UUID | None = None,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> Sequence[Poliza]:
        stmt = select(Poliza).options(
            selectinload(Poliza.vehiculo),
            selectinload(Poliza.deducibles),
            selectinload(Poliza.coberturas),
        )
        if owner_usuario_id is not None:
            stmt = stmt.join(Cliente, Poliza.cliente_id == Cliente.id).where(
                Cliente.usuario_id == owner_usuario_id
            )
        if estado is not None:
            stmt = stmt.where(Poliza.estado == estado)
        stmt = stmt.order_by(Poliza.created_at.desc()).offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return result.scalars().all()

    async def add(self, poliza: Poliza) -> Poliza:
        self.db.add(poliza)
        await self.db.flush()
        return poliza

    async def update(self, poliza: Poliza) -> Poliza:
        await self.db.commit()
        await self.db.refresh(poliza)
        return poliza

    async def historial(
        self,
        poliza_id: uuid.UUID,
        *,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> tuple[Sequence[HistorialCambio], int]:
        base_filter = (
            HistorialCambio.entidad == "polizas",
            HistorialCambio.entidad_id == poliza_id,
        )
        total_stmt = select(func.count()).select_from(HistorialCambio).where(*base_filter)
        total = (await self.db.execute(total_stmt)).scalar_one()

        items_stmt = (
            select(HistorialCambio)
            .where(*base_filter)
            .order_by(HistorialCambio.fecha.desc(), HistorialCambio.id.desc())
            .offset(skip)
            .limit(limit)
        )
        rows = (await self.db.execute(items_stmt)).scalars().all()
        return rows, total

    async def get_cliente(self, cliente_id: uuid.UUID) -> Cliente | None:
        return await self.db.get(Cliente, cliente_id)

    async def get_vehiculo(self, vehiculo_id: uuid.UUID) -> Vehiculo | None:
        return await self.db.get(Vehiculo, vehiculo_id)

    async def get_by_numero(self, numero_poliza: str) -> Poliza | None:
        res = await self.db.execute(select(Poliza).where(Poliza.numero_poliza == numero_poliza))
        return res.scalar_one_or_none()

    async def get_esquema(self, esquema_id: uuid.UUID) -> EsquemaPoliza | None:
        return await self.db.get(EsquemaPoliza, esquema_id)

    async def list_deducibles(self, poliza_id: uuid.UUID) -> Sequence[Deducible]:
        res = await self.db.execute(select(Deducible).where(Deducible.poliza_id == poliza_id))
        return res.scalars().all()

    async def add_extra(self, obj: object) -> None:
        self.db.add(obj)

    async def flush(self) -> None:
        await self.db.flush()

    async def commit(self) -> None:
        await self.db.commit()
