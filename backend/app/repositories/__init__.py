"""Repositories package initialization."""

from app.repositories.base import BaseRepository
from app.repositories.cliente_repository import ClienteRepository

__all__ = ["BaseRepository", "ClienteRepository"]
