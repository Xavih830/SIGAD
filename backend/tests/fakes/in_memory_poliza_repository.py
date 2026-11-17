"""In-memory fake implementation of PolizaRepositoryProtocol for unit testing without DB."""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime

from app.core.constants import DEFAULT_PAGE_LIMIT
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.cliente import Cliente
from app.models.deducible import Deducible
from app.models.esquema_poliza import EsquemaPoliza
from app.models.historial_cambio import HistorialCambio
from app.models.poliza import Poliza
from app.models.vehiculo import Vehiculo


class InMemoryPolizaRepository:
    """Adaptador en memoria de PolizaRepositoryProtocol sin dependencia de PostgreSQL."""

    def __init__(self) -> None:
        self.clientes: dict[uuid.UUID, Cliente] = {}
        self.vehiculos: dict[uuid.UUID, Vehiculo] = {}
        self.esquemas: dict[uuid.UUID, EsquemaPoliza] = {}
        self.polizas: dict[uuid.UUID, Poliza] = {}
        self.deducibles: dict[uuid.UUID, list[Deducible]] = {}
        self.historial_rows: list[HistorialCambio] = []
        self.extras: list[object] = []

    async def get(
        self,
        poliza_id: uuid.UUID,
        *,
        owner_usuario_id: uuid.UUID | None = None,
    ) -> Poliza | None:
        poliza = self.polizas.get(poliza_id)
        if poliza is None:
            return None
        if owner_usuario_id is not None:
            cliente = self.clientes.get(poliza.cliente_id)
            if cliente is None or cliente.usuario_id != owner_usuario_id:
                return None
        return poliza

    async def list(
        self,
        *,
        estado: EstadoPoliza | None = None,
        owner_usuario_id: uuid.UUID | None = None,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> Sequence[Poliza]:
        items = list(self.polizas.values())
        if owner_usuario_id is not None:
            items = [
                p
                for p in items
                if (cli := self.clientes.get(p.cliente_id)) is not None
                and cli.usuario_id == owner_usuario_id
            ]
        if estado is not None:
            items = [p for p in items if p.estado == estado]
        return items[skip : skip + limit]

    async def add(self, poliza: Poliza) -> Poliza:
        if poliza.id is None:
            poliza.id = uuid.uuid4()
        if poliza.version is None:
            poliza.version = 1
        now = datetime.now(UTC)
        if poliza.created_at is None:
            poliza.created_at = now
        if poliza.updated_at is None:
            poliza.updated_at = now
        if poliza.coberturas is None:
            poliza.coberturas = []
        if poliza.deducibles is None:
            poliza.deducibles = []
        self.polizas[poliza.id] = poliza
        return poliza

    async def update(self, poliza: Poliza) -> Poliza:
        poliza.updated_at = datetime.now(UTC)
        self.polizas[poliza.id] = poliza
        return poliza

    async def historial(
        self,
        poliza_id: uuid.UUID,
        *,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> tuple[Sequence[HistorialCambio], int]:
        filtered = [h for h in self.historial_rows if h.entidad_id == poliza_id]
        return filtered[skip : skip + limit], len(filtered)

    async def get_cliente(self, cliente_id: uuid.UUID) -> Cliente | None:
        return self.clientes.get(cliente_id)

    async def get_vehiculo(self, vehiculo_id: uuid.UUID) -> Vehiculo | None:
        return self.vehiculos.get(vehiculo_id)

    async def get_by_numero(self, numero_poliza: str) -> Poliza | None:
        for p in self.polizas.values():
            if p.numero_poliza == numero_poliza:
                return p
        return None

    async def get_esquema(self, esquema_id: uuid.UUID) -> EsquemaPoliza | None:
        return self.esquemas.get(esquema_id)

    async def list_deducibles(self, poliza_id: uuid.UUID) -> Sequence[Deducible]:
        return self.deducibles.get(poliza_id, [])

    async def add_extra(self, obj: object) -> None:
        self.extras.append(obj)
        if isinstance(obj, Deducible):
            self.deducibles.setdefault(obj.poliza_id, []).append(obj)
            if pol := self.polizas.get(obj.poliza_id):
                pol.deducibles.append(obj)

    async def flush(self) -> None:
        return None

    async def commit(self) -> None:
        return None
