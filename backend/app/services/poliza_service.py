"""Poliza domain service decoupled from SQLAlchemy via PolizaRepositoryProtocol."""

import uuid
from collections.abc import Sequence
from datetime import date, timedelta
from decimal import Decimal

from fastapi import HTTPException, status

from app.core.constants import (
    DEFAULT_PAGE_LIMIT,
    DIAS_PERIODO_CUOTA_MENSUAL,
    MAX_CUOTAS_POLIZA_ANUAL,
    MIN_CUOTAS_POLIZA,
)
from app.core.exceptions import ConflictoDominioException, RecursoNoEncontradoException
from app.domain.poliza_evaluator import (
    EstadoPoliza,
    validar_limite_vigencia_maxima,
    validar_y_calcular_estado_inicial,
)
from app.models.cobertura import Cobertura
from app.models.deducible import Deducible, TipoSiniestroEnum
from app.models.esquema_poliza import EsquemaPoliza
from app.models.pago import Pago
from app.models.poliza import Poliza
from app.models.usuario import RolEnum, Usuario
from app.repositories.poliza_repository import PolizaRepositoryProtocol
from app.schemas.base import PaginatedResponse
from app.schemas.poliza import (
    HistorialCambioResponse,
    PolizaCreate,
    PolizaUpdate,
    PolizaUpdateEstado,
)


def _validar_campos_esquema(esquema: EsquemaPoliza, campos_dict: dict) -> None:
    for regla in esquema.campos:
        nombre_campo = regla["nombre"]
        es_obligatorio = regla.get("es_obligatorio", False)
        tipo_campo = regla.get("tipo", "texto")

        if es_obligatorio and (
            nombre_campo not in campos_dict
            or campos_dict[nombre_campo] is None
            or campos_dict[nombre_campo] == ""
        ):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    f"Campo obligatorio '{nombre_campo}' requerido por el esquema "
                    f"'{esquema.codigo}' no fue suministrado."
                ),
            )

        if nombre_campo in campos_dict and campos_dict[nombre_campo] is not None:
            val = campos_dict[nombre_campo]
            if tipo_campo in ("numero", "entero"):
                if not isinstance(val, int) and not (isinstance(val, str) and val.isdigit()):
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"El campo '{nombre_campo}' debe ser de tipo numérico entero.",
                    )
            elif tipo_campo == "decimal":
                try:
                    float(val)
                except (ValueError, TypeError):
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"El campo '{nombre_campo}' debe ser de tipo decimal.",
                    ) from None
            elif tipo_campo == "booleano" and not isinstance(val, bool) and str(val).lower() not in (
                "true",
                "false",
                "1",
                "0",
            ):
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"El campo '{nombre_campo}' debe ser de tipo booleano.",
                )


class PolizaService:
    """Servicio de aplicación para el ciclo de vida de pólizas."""

    def __init__(self, repo: PolizaRepositoryProtocol) -> None:
        self.repo = repo

    async def crear_poliza(self, payload: PolizaCreate) -> Poliza:
        cliente = await self.repo.get_cliente(payload.cliente_id)
        if not cliente:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Cliente con ID {payload.cliente_id} no existe.",
            )

        vehiculo = await self.repo.get_vehiculo(payload.vehiculo_id)
        if not vehiculo:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Vehículo con ID {payload.vehiculo_id} no existe.",
            )

        if await self.repo.get_by_numero(payload.numero_poliza):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Ya existe una póliza con número {payload.numero_poliza}.",
            )

        estado_inicial = validar_y_calcular_estado_inicial(
            payload.fecha_inicio, payload.fecha_fin, date.today()
        )
        validar_limite_vigencia_maxima(payload.fecha_inicio, payload.fecha_fin)

        if payload.esquema_id:
            esquema_poliza = await self.repo.get_esquema(payload.esquema_id)
            if not esquema_poliza:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Esquema de póliza con ID {payload.esquema_id} no existe.",
                )
            _validar_campos_esquema(esquema_poliza, payload.campos_adicionales or {})

        poliza = Poliza(
            numero_poliza=payload.numero_poliza,
            cliente_id=payload.cliente_id,
            vehiculo_id=payload.vehiculo_id,
            inspeccion_id=payload.inspeccion_id,
            esquema_id=payload.esquema_id,
            fecha_inicio=payload.fecha_inicio,
            fecha_fin=payload.fecha_fin,
            estado=estado_inicial,
            valor_asegurado=payload.valor_asegurado,
            prima_mensual=payload.prima_mensual,
            kilometraje_emision=payload.kilometraje_emision,
            campos_adicionales=payload.campos_adicionales,
        )
        await self.repo.add(poliza)

        if payload.deducibles:
            for d in payload.deducibles:
                await self.repo.add_extra(
                    Deducible(
                        poliza_id=poliza.id,
                        tipo_siniestro=d.tipo_siniestro,
                        porcentaje_valor=d.porcentaje_valor,
                        monto_minimo_usd=d.monto_minimo_usd,
                    )
                )
        else:
            await self.repo.add_extra(
                Deducible(
                    poliza_id=poliza.id,
                    tipo_siniestro=TipoSiniestroEnum.GENERAL,
                    porcentaje_valor=Decimal("10.00"),
                    monto_minimo_usd=Decimal("200.00"),
                )
            )

        if payload.coberturas:
            for c in payload.coberturas:
                await self.repo.add_extra(
                    Cobertura(poliza_id=poliza.id, nombre=c.nombre, monto=c.monto)
                )

        dias_totales = (payload.fecha_fin - payload.fecha_inicio).days
        num_cuotas = max(
            MIN_CUOTAS_POLIZA,
            min(MAX_CUOTAS_POLIZA_ANUAL, round(dias_totales / DIAS_PERIODO_CUOTA_MENSUAL)),
        )
        for i in range(MIN_CUOTAS_POLIZA, num_cuotas + 1):
            vencimiento = payload.fecha_inicio + timedelta(
                days=DIAS_PERIODO_CUOTA_MENSUAL * (i - 1)
            )
            await self.repo.add_extra(
                Pago(
                    poliza_id=poliza.id,
                    numero_cuota=i,
                    monto_usd=payload.prima_mensual,
                    fecha_vencimiento=vencimiento,
                    estado="pendiente",
                )
            )

        await self.repo.commit()
        created = await self.repo.get(poliza.id)
        return created if created is not None else poliza

    async def listar_polizas(
        self,
        *,
        current_user: Usuario,
        estado: EstadoPoliza | None = None,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> Sequence[Poliza]:
        owner_id = current_user.id if current_user.rol == RolEnum.CLIENTE else None
        return await self.repo.list(
            estado=estado,
            owner_usuario_id=owner_id,
            skip=skip,
            limit=limit,
        )

    async def obtener_poliza(self, poliza_id: uuid.UUID, *, current_user: Usuario) -> Poliza:
        owner_id = current_user.id if current_user.rol == RolEnum.CLIENTE else None
        poliza = await self.repo.get(poliza_id, owner_usuario_id=owner_id)
        if not poliza:
            raise RecursoNoEncontradoException("Recurso no encontrado.")
        return poliza

    async def consultar_deducibles(
        self, poliza_id: uuid.UUID, *, current_user: Usuario
    ) -> Sequence[Deducible]:
        await self.obtener_poliza(poliza_id, current_user=current_user)
        return await self.repo.list_deducibles(poliza_id)

    async def actualizar_estado(
        self, poliza_id: uuid.UUID, payload: PolizaUpdateEstado
    ) -> Poliza:
        poliza = await self.repo.get(poliza_id)
        if not poliza:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Póliza no encontrada.",
            )
        poliza.estado = payload.estado
        return await self.repo.update(poliza)

    async def actualizar_poliza(
        self, poliza_id: uuid.UUID, payload: PolizaUpdate
    ) -> Poliza:
        poliza = await self.repo.get(poliza_id)
        if not poliza:
            raise RecursoNoEncontradoException("Recurso no encontrado.")

        if payload.version != poliza.version:
            raise ConflictoDominioException(
                "Conflicto de versión: la póliza fue modificada por otro usuario."
            )

        nueva_inicio = (
            payload.fecha_inicio if payload.fecha_inicio is not None else poliza.fecha_inicio
        )
        nueva_fin = payload.fecha_fin if payload.fecha_fin is not None else poliza.fecha_fin
        if nueva_inicio != poliza.fecha_inicio or nueva_fin != poliza.fecha_fin:
            validar_y_calcular_estado_inicial(nueva_inicio, nueva_fin, date.today())
            validar_limite_vigencia_maxima(nueva_inicio, nueva_fin)

        campos_cambiados = False
        if payload.fecha_inicio is not None and payload.fecha_inicio != poliza.fecha_inicio:
            poliza.fecha_inicio = payload.fecha_inicio
            campos_cambiados = True
        if payload.fecha_fin is not None and payload.fecha_fin != poliza.fecha_fin:
            poliza.fecha_fin = payload.fecha_fin
            campos_cambiados = True
        if (
            payload.valor_asegurado is not None
            and payload.valor_asegurado != poliza.valor_asegurado
        ):
            poliza.valor_asegurado = payload.valor_asegurado
            campos_cambiados = True
        if payload.prima_mensual is not None and payload.prima_mensual != poliza.prima_mensual:
            poliza.prima_mensual = payload.prima_mensual
            campos_cambiados = True
        if payload.esquema_id is not None and payload.esquema_id != poliza.esquema_id:
            poliza.esquema_id = payload.esquema_id
            campos_cambiados = True
        if (
            payload.campos_adicionales is not None
            and payload.campos_adicionales != poliza.campos_adicionales
        ):
            poliza.campos_adicionales = payload.campos_adicionales
            campos_cambiados = True

        if payload.coberturas is not None:
            actuales = sorted((c.nombre, Decimal(c.monto)) for c in poliza.coberturas)
            nuevas = sorted((c.nombre, Decimal(c.monto)) for c in payload.coberturas)
            if actuales != nuevas:
                poliza.coberturas.clear()
                await self.repo.flush()
                for c in payload.coberturas:
                    poliza.coberturas.append(
                        Cobertura(poliza_id=poliza.id, nombre=c.nombre, monto=c.monto)
                    )
                campos_cambiados = True

        if not campos_cambiados:
            return poliza

        poliza.version += 1
        return await self.repo.update(poliza)

    async def listar_historial(
        self,
        poliza_id: uuid.UUID,
        *,
        current_user: Usuario,
        skip: int = 0,
        limit: int = DEFAULT_PAGE_LIMIT,
    ) -> PaginatedResponse[HistorialCambioResponse]:
        await self.obtener_poliza(poliza_id, current_user=current_user)
        rows, total = await self.repo.historial(poliza_id, skip=skip, limit=limit)
        items = [HistorialCambioResponse.model_validate(r) for r in rows]
        return PaginatedResponse(items=items, total=total, skip=skip, limit=limit)
