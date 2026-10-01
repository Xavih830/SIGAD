"""Async factories for creating persistent SQLAlchemy models within test transactions."""

from datetime import date, timedelta
from decimal import Decimal
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.cliente import Cliente
from app.models.cobertura import Cobertura
from app.models.deducible import Deducible, TipoSiniestroEnum
from app.models.pago import Pago
from app.models.poliza import Poliza
from app.models.usuario import RolEnum, Usuario
from app.models.vehiculo import Vehiculo
from tests.factories.helpers import generar_cedula_valida, generar_placa_valida


async def create_user(
    session: AsyncSession,
    *,
    email: str | None = None,
    password: str = "TestPass1234!*",
    nombre: str = "Usuario Test",
    rol: RolEnum = RolEnum.CLIENTE,
    activo: bool = True,
) -> Usuario:
    """Create and persist a User model."""
    uid = uuid.uuid4().hex[:6]
    user = Usuario(
        email=email or f"user_{uid}@test.sigad.ec",
        password_hash=hash_password(password),
        nombre=nombre,
        rol=rol,
        activo=activo,
    )
    session.add(user)
    await session.flush()
    return user


async def create_cliente(
    session: AsyncSession,
    *,
    usuario_id: uuid.UUID | None = None,
    identificacion: str | None = None,
    nombres: str = "Cliente de Prueba",
    email: str | None = None,
    telefono: str = "0991234567",
) -> Cliente:
    """Create and persist a Client model with guaranteed Módulo 10 cédula."""
    uid = uuid.uuid4().hex[:6]
    cliente = Cliente(
        identificacion=identificacion or generar_cedula_valida(),
        nombres=nombres,
        email=email or f"cliente_{uid}@test.sigad.ec",
        telefono=telefono,
        usuario_id=usuario_id,
    )
    session.add(cliente)
    await session.flush()
    return cliente


async def create_vehiculo(
    session: AsyncSession,
    *,
    cliente_id: uuid.UUID,
    placa: str | None = None,
    marca: str = "Toyota",
    modelo: str = "Corolla Cross XEI",
    anio: int = 2023,
) -> Vehiculo:
    """Create and persist a Vehicle model with ANT-compliant license plate."""
    vehiculo = Vehiculo(
        cliente_id=cliente_id,
        placa=placa or generar_placa_valida(),
        marca=marca,
        modelo=modelo,
        anio=anio,
    )
    session.add(vehiculo)
    await session.flush()
    return vehiculo


async def create_poliza(
    session: AsyncSession,
    *,
    cliente_id: uuid.UUID,
    vehiculo_id: uuid.UUID,
    numero_poliza: str | None = None,
    fecha_inicio: date | None = None,
    fecha_fin: date | None = None,
    estado: EstadoPoliza = EstadoPoliza.ACTIVA,
    valor_asegurado: Decimal = Decimal("20000.00"),
    prima_mensual: Decimal = Decimal("65.00"),
    kilometraje_emision: int = 15000,
    with_default_deductible: bool = True,
) -> Poliza:
    """Create and persist a Policy model with associated deductibles."""
    f_ini = fecha_inicio or date.today()
    f_fin = fecha_fin or (f_ini + timedelta(days=365))
    num = numero_poliza or f"POL-TEST-{uuid.uuid4().hex[:6].upper()}"

    poliza = Poliza(
        numero_poliza=num,
        cliente_id=cliente_id,
        vehiculo_id=vehiculo_id,
        fecha_inicio=f_ini,
        fecha_fin=f_fin,
        estado=estado,
        valor_asegurado=valor_asegurado,
        prima_mensual=prima_mensual,
        kilometraje_emision=kilometraje_emision,
    )
    session.add(poliza)
    await session.flush()

    if with_default_deductible:
        deducible = Deducible(
            poliza_id=poliza.id,
            tipo_siniestro=TipoSiniestroEnum.GENERAL,
            porcentaje_valor=Decimal("10.00"),
            monto_minimo_usd=Decimal("200.00"),
        )
        session.add(deducible)
        await session.flush()

    return poliza


async def create_pago(
    session: AsyncSession,
    *,
    poliza_id: uuid.UUID,
    numero_cuota: int = 1,
    monto_usd: Decimal = Decimal("70.00"),
    fecha_vencimiento: date | None = None,
    fecha_pago: date | None = None,
    estado: str = "pendiente",
    metodo_pago: str | None = None,
    comprobante_ref: str | None = None,
) -> Pago:
    """Create and persist a Pago installment model."""
    f_venc = fecha_vencimiento or date.today()
    pago = Pago(
        poliza_id=poliza_id,
        numero_cuota=numero_cuota,
        monto_usd=monto_usd,
        fecha_vencimiento=f_venc,
        fecha_pago=fecha_pago,
        estado=estado,
        metodo_pago=metodo_pago,
        comprobante_ref=comprobante_ref,
    )
    session.add(pago)
    await session.flush()
    return pago
