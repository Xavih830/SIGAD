"""Async factories for creating persistent SQLAlchemy models within test transactions."""

from datetime import date, timedelta
from decimal import Decimal
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import (
    MIN_CUOTAS_POLIZA,
    OCR_DEFAULT_KILOMETRAJE,
    OCR_DEFAULT_PRIMA_MENSUAL,
    OCR_DEFAULT_VALOR_ASEGURADO,
)
from app.core.security import hash_password
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.asistencia import Asistencia
from app.models.cliente import Cliente
from app.models.deducible import Deducible, TipoSiniestroEnum
from app.models.documento import Documento, EstadoExtraccionEnum
from app.models.inspeccion import Inspeccion
from app.models.pago import Pago
from app.models.poliza import Poliza
from app.models.resultado_extraccion import ResultadoExtraccion
from app.models.taller import Taller
from app.models.usuario import RolEnum, Usuario
from app.models.vehiculo import Vehiculo
from tests.factories.fixtures import (
    ASISTENCIA_DESCRIPCION,
    ASISTENCIA_ICONO,
    ASISTENCIA_TELEFONO,
    ASISTENCIA_TITULO,
    CLIENTE_NAME,
    CLIENTE_PASSWORD,
    DEFAULT_CAMPOS_EXTRAIDOS,
    TALLER_CIUDAD,
    TALLER_DIRECCION,
    TALLER_NOMBRE,
    TALLER_TELEFONO,
)
from tests.factories.helpers import generar_cedula_valida, generar_placa_valida


async def create_user(
    session: AsyncSession,
    *,
    email: str | None = None,
    password: str = CLIENTE_PASSWORD,
    nombre: str = CLIENTE_NAME,
    rol: RolEnum = RolEnum.CLIENTE,
    activo: bool = True,
) -> Usuario:
    """Create and persist a User model using canonical defaults."""
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
    nombres: str = CLIENTE_NAME,
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
    valor_asegurado: Decimal = OCR_DEFAULT_VALOR_ASEGURADO,
    prima_mensual: Decimal = OCR_DEFAULT_PRIMA_MENSUAL,
    kilometraje_emision: int = OCR_DEFAULT_KILOMETRAJE,
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
    numero_cuota: int = MIN_CUOTAS_POLIZA,
    monto_usd: Decimal = OCR_DEFAULT_PRIMA_MENSUAL,
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


async def create_inspeccion(
    session: AsyncSession,
    *,
    vehiculo_id: uuid.UUID,
    kilometraje: int = OCR_DEFAULT_KILOMETRAJE,
    observaciones: str = "Inspección técnica",
    id: uuid.UUID | None = None,
) -> Inspeccion:
    """Create and persist an Inspeccion model."""
    inspeccion = Inspeccion(
        id=id or uuid.uuid4(),
        vehiculo_id=vehiculo_id,
        kilometraje=kilometraje,
        observaciones=observaciones,
    )
    session.add(inspeccion)
    await session.flush()
    return inspeccion


async def create_taller(
    session: AsyncSession,
    *,
    id: uuid.UUID | None = None,
    nombre: str = TALLER_NOMBRE,
    ciudad: str = TALLER_CIUDAD,
    direccion: str = TALLER_DIRECCION,
    telefono: str = TALLER_TELEFONO,
    activo: bool = True,
) -> Taller:
    """Create and persist a Taller model."""
    taller = Taller(
        id=id or uuid.uuid4(),
        nombre=nombre,
        ciudad=ciudad,
        direccion=direccion,
        telefono=telefono,
        activo=activo,
    )
    session.add(taller)
    await session.flush()
    return taller


async def create_asistencia(
    session: AsyncSession,
    *,
    id: uuid.UUID | None = None,
    titulo: str = ASISTENCIA_TITULO,
    descripcion: str = ASISTENCIA_DESCRIPCION,
    telefono_emergencia: str = ASISTENCIA_TELEFONO,
    icono: str = ASISTENCIA_ICONO,
    activo: bool = True,
) -> Asistencia:
    """Create and persist an Asistencia model."""
    asistencia = Asistencia(
        id=id or uuid.uuid4(),
        titulo=titulo,
        descripcion=descripcion,
        telefono_emergencia=telefono_emergencia,
        icono=icono,
        activo=activo,
    )
    session.add(asistencia)
    await session.flush()
    return asistencia


async def create_documento(
    session: AsyncSession,
    *,
    id: uuid.UUID | None = None,
    poliza_id: uuid.UUID | None = None,
    nombre_archivo: str = "documento_test.pdf",
    ruta_archivo: str | None = None,
    tipo_mime: str = "application/pdf",
    tamano_bytes: int = 10240,
    hash_sha256: str | None = None,
    estado_extraccion: str = EstadoExtraccionEnum.REQUIERE_REVISION_MANUAL.value,
    intentos: int = 0,
) -> Documento:
    """Create and persist a Documento model."""
    doc_id = id or uuid.uuid4()
    doc = Documento(
        id=doc_id,
        poliza_id=poliza_id,
        nombre_archivo=nombre_archivo,
        ruta_archivo=ruta_archivo or f"uploads/{doc_id}.pdf",
        tipo_mime=tipo_mime,
        tamano_bytes=tamano_bytes,
        hash_sha256=hash_sha256 or "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        estado_extraccion=estado_extraccion,
        intentos=intentos,
    )
    session.add(doc)
    await session.flush()
    return doc


async def create_resultado_extraccion(
    session: AsyncSession,
    *,
    documento_id: uuid.UUID,
    texto_completo: str = "Documento vehicular escaneado",
    metodo: str = "pdfplumber",
    confianza: Decimal = Decimal("85.00"),
    campos_extraidos: dict | None = None,
    id: uuid.UUID | None = None,
) -> ResultadoExtraccion:
    """Create and persist a ResultadoExtraccion model."""
    res = ResultadoExtraccion(
        id=id or uuid.uuid4(),
        documento_id=documento_id,
        texto_completo=texto_completo,
        metodo=metodo,
        confianza=confianza,
        campos_extraidos=campos_extraidos if campos_extraidos is not None else DEFAULT_CAMPOS_EXTRAIDOS.copy(),
    )
    session.add(res)
    await session.flush()
    return res

