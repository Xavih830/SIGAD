"""Authentication endpoint — polymorphic login (email or cédula).

Security invariants:
1. If `@` is in the identifier → search by email in `usuarios`.
2. If purely numeric → search by cédula via JOIN `clientes` → `usuarios`.
3. If user not found → verify against DUMMY_HASH to maintain constant-time.
4. Error response is always the same generic message (anti-enumeration).
"""

import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_client_ip
from app.core.exceptions import EmailDuplicadoException
from app.core.rate_limit import rate_limiter
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_dummy,
    verify_dummy_otp,
    verify_otp_hmac,
    verify_password,
)
from app.db.session import get_db
from app.models.cliente import Cliente
from app.models.codigo_vinculacion import CodigoVinculacion
from app.models.usuario import RolEnum, Usuario
from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.cliente import VinculacionRequest

logger = logging.getLogger("sigad.auth")

router = APIRouter(prefix="/auth", tags=["Auth"])

# Uniform error — same message regardless of whether user exists or password is wrong
_LOGIN_ERROR = "Las credenciales ingresadas no son válidas."
_VINCULACION_ERROR = "Código de vinculación inválido o expirado."


@router.post("/login", response_model=TokenResponse)
async def login(
    body: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Polymorphic login: email → direct lookup, cédula → join through clientes."""
    ip = get_client_ip(request)
    identificador = body.identificador.strip()

    # Rate limiting (Layers 1, 2, 3, 4)
    await rate_limiter.check_all(ip=ip, identity=identificador, endpoint="login")

    if "@" in identificador:
        # Email-based lookup
        stmt = select(Usuario).where(Usuario.email == identificador.lower())
    else:
        # Cédula-based lookup via clientes JOIN
        stmt = (
            select(Usuario)
            .join(Cliente, Cliente.usuario_id == Usuario.id)
            .where(Cliente.identificacion == identificador)
        )

    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None or not user.activo:
        # Constant-time defense: run Argon2 verify against dummy hash
        await verify_dummy(body.password)
        rate_limiter.record_failure(identity=identificador, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_LOGIN_ERROR,
        )

    # Real password verification (runs in thread via asyncio.to_thread)
    is_valid = await verify_password(body.password, user.password_hash)
    if not is_valid:
        rate_limiter.record_failure(identity=identificador, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_LOGIN_ERROR,
        )

    rate_limiter.record_success(identity=identificador, ip=ip)

    # Build JWT payload
    jti = str(uuid.uuid4())
    token_data = {"sub": str(user.id), "rol": user.rol.value, "jti": jti}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    logger.info("login_ok user_id=%s rol=%s", user.id, user.rol.value)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": str(user.id),
            "email": user.email,
            "nombre": user.nombre,
            "rol": user.rol.value,
        },
    )


@router.post("/vinculacion", response_model=TokenResponse)
async def vincular_cliente(
    body: VinculacionRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Flujo de vinculación móvil para clientes asegurados."""
    ip = get_client_ip(request)
    cedula = body.cedula.strip()

    # 1. Rate limiting en 4 capas
    await rate_limiter.check_all(ip=ip, identity=cedula, endpoint="vinculacion")

    # 2. Búsqueda de cliente por cédula
    stmt_cliente = select(Cliente).where(Cliente.identificacion == cedula)
    res_cliente = await db.execute(stmt_cliente)
    cliente = res_cliente.scalar_one_or_none()

    if not cliente:
        # Defensa de tiempo constante estructural ante cédula no registrada
        await verify_dummy(body.password)
        verify_dummy_otp(body.codigo_otp)
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_VINCULACION_ERROR,
        )

    # Defensa contra Account Takeover: impedir re-vinculación de cuentas ya activas
    if cliente.usuario_id is not None:
        await verify_dummy(body.password)
        verify_dummy_otp(body.codigo_otp)
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El cliente ya se encuentra vinculado a una cuenta de usuario.",
        )

    # 3. Determinación y verificación estricta de colisión de email
    target_email = body.email_opcional or cliente.email
    if not target_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe proporcionar un correo electrónico para completar la vinculación.",
        )
    target_email = target_email.strip().lower()

    # Detección de colisión: si el correo ya existe en usuarios, abortar ANTES de tocar la DB
    stmt_email_check = select(Usuario).where(Usuario.email == target_email)
    res_email_check = await db.execute(stmt_email_check)
    existing_user_email = res_email_check.scalar_one_or_none()

    if existing_user_email is not None:
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise EmailDuplicadoException("El correo electrónico ya se encuentra registrado")

    # 4. Verificación de código OTP activo
    stmt_otp = (
        select(CodigoVinculacion)
        .where(
            CodigoVinculacion.cliente_id == cliente.id,
            CodigoVinculacion.consumido.is_(False),
        )
        .order_by(desc(CodigoVinculacion.created_at))
        .limit(1)
    )
    res_otp = await db.execute(stmt_otp)
    codigo_obj = res_otp.scalar_one_or_none()

    now_utc = datetime.now(timezone.utc)

    if not codigo_obj or codigo_obj.expira_en < now_utc:
        await verify_dummy(body.password)
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_VINCULACION_ERROR,
        )

    # Validación criptográfica con HMAC-SHA256 (rotación trimestral)
    is_valid_otp = verify_otp_hmac(body.codigo_otp, codigo_obj.codigo_hmac)

    if not is_valid_otp:
        codigo_obj.intentos_fallidos += 1
        # Al tercer intento fallido consecutivo: invalidar código inmediatamente
        if codigo_obj.intentos_fallidos >= 3:
            codigo_obj.consumido = True
        await db.commit()
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_VINCULACION_ERROR,
        )

    # 5. Código OTP válido: marcar como consumido y crear usuario
    codigo_obj.consumido = True

    nuevo_usuario = Usuario(
        email=target_email,
        password_hash=hash_password(body.password),
        nombre=cliente.nombres,
        rol=RolEnum.CLIENTE,
        activo=True,
    )
    db.add(nuevo_usuario)
    await db.flush()

    cliente.usuario_id = nuevo_usuario.id
    cliente.email = target_email
    await db.commit()
    await db.refresh(nuevo_usuario)

    rate_limiter.record_success(identity=cedula, ip=ip)

    # 6. Generación de tokens de acceso
    jti = str(uuid.uuid4())
    token_data = {"sub": str(nuevo_usuario.id), "rol": nuevo_usuario.rol.value, "jti": jti}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    logger.info("vinculacion_exitosa cliente_id=%s usuario_id=%s", cliente.id, nuevo_usuario.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": str(nuevo_usuario.id),
            "email": nuevo_usuario.email,
            "nombre": nuevo_usuario.nombre,
            "rol": nuevo_usuario.rol.value,
        },
    )

