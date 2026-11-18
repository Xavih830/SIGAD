"""Cliente repository implementation."""

from collections.abc import Sequence

from sqlalchemy import desc, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import DEFAULT_PAGE_LIMIT
from app.models.cliente import Cliente
from app.repositories.base import BaseRepository


class ClienteRepository(BaseRepository[Cliente]):
    """Repository handling database access for Cliente entities."""

    model = Cliente

    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db)

    async def get_by_identificacion(self, identificacion: str) -> Cliente | None:
        """Find client by identification (cédula or RUC)."""
        stmt = select(Cliente).where(Cliente.identificacion == identificacion)
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def search(
        self,
        q: str | None = None,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> tuple[Sequence[Cliente], int]:
        """Search clients by name or identification with pagination."""
        filters = []
        if q and q.strip():
            clean_q = f"%{q.strip()}%"
            filters.append(
                or_(
                    Cliente.nombres.ilike(clean_q),
                    Cliente.identificacion.ilike(clean_q),
                )
            )

        return await self.list(
            filters=filters,
            order_by=desc(Cliente.created_at),
            skip=skip,
            limit=limit,
        )
