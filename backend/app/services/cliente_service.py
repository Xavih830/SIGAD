"""Domain service for managing clients, lifecycle, and linking OTPs."""

import logging
import uuid
from collections.abc import Sequence
from datetime import UTC, datetime, timedelta

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.constants import DEFAULT_PAGE_LIMIT
from app.core.exceptions import (
    ConflictoDominioException,
    IdentificacionDuplicadaException,
    RecursoNoEncontradoException,
)
from app.core.security import compute_otp_hmac, generate_otp_code
from app.models.cliente import Cliente
from app.models.codigo_vinculacion import CodigoVinculacion
from app.models.poliza import Poliza
from app.repositories.cliente_repository import ClienteRepository
from app.schemas.cliente import ClienteCreate, ClienteUpdate

logger = logging.getLogger("sigad.services.cliente")


class ClienteService:
    """Service encapsulating business invariants and lifecycle operations for Cliente."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = ClienteRepository(db)

    async def registrar(
        self,
        datos: ClienteCreate,
    ) -> tuple[Cliente, str]:
        """Registra un nuevo cliente y emite su código OTP de vinculación inicial.

        Retorna la tupla (cliente, codigo_otp_plano).
        """
        identificacion = datos.identificacion.strip()
        existing = await self.repo.get_by_identificacion(identificacion)
        if existing:
            raise IdentificacionDuplicadaException()

        nuevo_cliente = Cliente(
            identificacion=identificacion,
            nombres=datos.nombres.strip(),
            email=datos.email.lower() if datos.email else None,
            telefono=datos.telefono.strip() if datos.telefono else None,
        )
        try:
            await self.repo.add(nuevo_cliente)
            codigo_plano = generate_otp_code(6)
            codigo_hmac = compute_otp_hmac(codigo_plano, settings.OTP_SECRET_KEY_ACTUAL)
            expira_en = datetime.now(UTC) + timedelta(minutes=settings.OTP_EXPIRATION_MINUTES)

            codigo_obj = CodigoVinculacion(
                cliente_id=nuevo_cliente.id,
                codigo_hmac=codigo_hmac,
                expira_en=expira_en,
                consumido=False,
                intentos_fallidos=0,
            )
            self.db.add(codigo_obj)
            await self.db.commit()
            await self.db.refresh(nuevo_cliente)
        except IntegrityError:
            await self.db.rollback()
            raise IdentificacionDuplicadaException() from None

        logger.info("cliente_registrado id=%s", nuevo_cliente.id)
        return nuevo_cliente, codigo_plano

    async def listar(
        self,
        q: str | None = None,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> tuple[Sequence[Cliente], int]:
        """Lista clientes con búsqueda opcional y devuelve (items, total)."""
        return await self.repo.search(q=q, skip=skip, limit=limit)

    async def obtener(self, cliente_id: uuid.UUID) -> Cliente:
        """Obtiene un cliente por ID o lanza RecursoNoEncontradoException."""
        cliente = await self.repo.get(cliente_id)
        if not cliente:
            raise RecursoNoEncontradoException("Recurso no encontrado.")
        return cliente

    async def actualizar(
        self,
        cliente_id: uuid.UUID,
        datos: ClienteUpdate,
    ) -> Cliente:
        """Actualiza datos de contacto del cliente.

        Nota arquitectónica: La identificación no es editable.
        Si cambia el email y el cliente tiene un usuario_id asociado, el email
        en la tabla `usuarios` no se altera automáticamente para preservar
        la identidad de autenticación existente.
        """
        cliente = await self.obtener(cliente_id)

        update_data = datos.model_dump(exclude_unset=True)
        if "nombres" in update_data and update_data["nombres"] is not None:
            cliente.nombres = update_data["nombres"].strip()
        if "email" in update_data:
            cliente.email = update_data["email"].lower() if update_data["email"] else None
        if "telefono" in update_data:
            cliente.telefono = update_data["telefono"].strip() if update_data["telefono"] else None

        await self.db.commit()
        await self.db.refresh(cliente)
        logger.info("cliente_actualizado id=%s", cliente.id)
        return cliente

    async def eliminar(self, cliente_id: uuid.UUID) -> None:
        """Elimina un cliente si no registra pólizas ni vehículos asociados."""
        cliente = await self.obtener(cliente_id)

        stmt_polizas = select(Poliza).where(Poliza.cliente_id == cliente_id).limit(1)
        res_polizas = await self.db.execute(stmt_polizas)
        if res_polizas.scalar_one_or_none():
            raise ConflictoDominioException("No se puede eliminar el cliente porque tiene registros asociados.")

        from app.models.vehiculo import Vehiculo
        stmt_vehiculos = select(Vehiculo).where(Vehiculo.cliente_id == cliente_id).limit(1)
        res_vehiculos = await self.db.execute(stmt_vehiculos)
        if res_vehiculos.scalar_one_or_none():
            raise ConflictoDominioException("No se puede eliminar el cliente porque tiene registros asociados.")

        await self.repo.delete(cliente)
        await self.db.commit()
        logger.info("cliente_eliminado id=%s", cliente_id)

    async def regenerar_otp(self, cliente_id: uuid.UUID) -> tuple[Cliente, str]:
        """Regenera código OTP para cliente sin usuario vinculado."""
        cliente = await self.obtener(cliente_id)
        if cliente.usuario_id is not None:
            raise ConflictoDominioException("El cliente ya tiene una cuenta de usuario vinculada.")

        await self.db.execute(
            update(CodigoVinculacion)
            .where(
                CodigoVinculacion.cliente_id == cliente.id,
                CodigoVinculacion.consumido.is_(False),
            )
            .values(consumido=True)
        )

        codigo_plano = generate_otp_code(6)
        codigo_hmac = compute_otp_hmac(codigo_plano, settings.OTP_SECRET_KEY_ACTUAL)
        expira_en = datetime.now(UTC) + timedelta(minutes=settings.OTP_EXPIRATION_MINUTES)

        codigo_obj = CodigoVinculacion(
            cliente_id=cliente.id,
            codigo_hmac=codigo_hmac,
            expira_en=expira_en,
            consumido=False,
            intentos_fallidos=0,
        )
        self.db.add(codigo_obj)
        await self.db.commit()
        await self.db.refresh(cliente)

        logger.info("otp_regenerado cliente_id=%s", cliente.id)
        return cliente, codigo_plano
