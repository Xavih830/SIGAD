"""Base generic repository for SQLAlchemy models."""

import uuid
from collections.abc import Sequence
from typing import Generic, TypeVar

from sqlalchemy import ColumnElement, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import DEFAULT_PAGE_LIMIT

ModelT = TypeVar("ModelT")


class BaseRepository(Generic[ModelT]):
    """Generic repository providing basic CRUD primitives without managing transactions."""

    model: type[ModelT]

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get(self, id: uuid.UUID) -> ModelT | None:
        """Fetch entity by primary key."""
        return await self.db.get(self.model, id)

    async def list(
        self,
        *,
        filters: Sequence[ColumnElement[bool]] = (),
        order_by=None,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> tuple[Sequence[ModelT], int]:
        """Fetch paginated entities and the overall count matching filters."""
        query = select(self.model)
        count_query = select(func.count()).select_from(self.model)

        if filters:
            for f in filters:
                query = query.where(f)
                count_query = count_query.where(f)

        total = await self.db.scalar(count_query) or 0

        if order_by is not None:
            query = query.order_by(order_by)

        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        items = result.scalars().all()

        return items, total

    async def add(self, obj: ModelT) -> ModelT:
        """Add object to session and flush to generate database-side defaults/IDs."""
        self.db.add(obj)
        await self.db.flush()
        return obj

    async def delete(self, obj: ModelT) -> None:
        """Delete object from session and flush."""
        await self.db.delete(obj)
        await self.db.flush()
