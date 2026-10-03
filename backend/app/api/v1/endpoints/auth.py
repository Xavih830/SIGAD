"""Authentication endpoint — polymorphic login (email or cédula).

Security invariants:
1. If `@` is in the identifier → search by email in `usuarios`.
2. If purely numeric → search by cédula via JOIN `clientes` → `usuarios`.
3. If user not found → verify against DUMMY_HASH to maintain constant-time.
4. Error response is always the same generic message (anti-enumeration).
"""

import logging
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_client_ip
from app.core.exceptions import EmailDuplicadoException
from app.core.rate_limit import rate_limiter
from app.core.security import (
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
from app.schemas.auth import LoginRequest, RefreshRequest, TokenResponse
from app.schemas.cliente import VinculacionRequest
from app.services.sesion_service import emitir_sesion, revocar_familia, rotar_sesion

logger = logging.getLogger("sigad.auth")

router = APIRouter(prefix="/auth", tags=["Auth"])

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

    await rate_limiter.check_all(ip=ip, identity=identificador, endpoint="login")

    if "@" in identificador:
        stmt = select(Usuario).where(Usuario.email == identificador.lower())
    else:
        stmt = (
            select(Usuario)
            .join(Cliente, Cliente.usuario_id == Usuario.id)
            .where(Cliente.identificacion == identificador)
        )

    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None or not user.activo:
        await verify_dummy(body.password)
        rate_limiter.record_failure(identity=identificador, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_LOGIN_ERROR,
        )

    is_valid = await verify_password(body.password, user.password_hash)
    if not is_valid:
        rate_limiter.record_failure(identity=identificador, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_LOGIN_ERROR,
        )

    rate_limiter.record_success(identity=identificador, ip=ip)

    access_token, refresh_token = await emitir_sesion(db, user)
    await db.commit()

    logger.info("login_ok user_id=%s rol=%s", user.id, user.rol.value)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": str(user.id),
            "email": user.email,
            "nombre": user.nombre,
            "rol": user.rol.value,
            "activo": user.activo,
        },
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_session(
    body: RefreshRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Rota un refresh token válido emitiendo un nuevo par access/refresh."""
    ip = get_client_ip(request)
    rate_limiter.check_ip(ip=ip, endpoint="refresh")
    rate_limiter.record_ip(ip=ip, endpoint="refresh")

    user, access_token, new_refresh = await rotar_sesion(db, body.refresh_token)

    logger.info("refresh_ok user_id=%s rol=%s", user.id, user.rol.value)

    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh,
        user={
            "id": str(user.id),
            "email": user.email,
            "nombre": user.nombre,
            "rol": user.rol.value,
            "activo": user.activo,
        },
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    body: RefreshRequest,
    db: AsyncSession = Depends(get_db),
) -> None:
    """Revoca la familia de sesiones asociada al refresh token para cerrar sesión."""
    await revocar_familia(db, body.refresh_token)



async def _validar_y_consumir_otp_vinculacion(
    db: AsyncSession,
    cliente_id: uuid.UUID,
    codigo_otp: str,
    password_plano: str,
    cedula: str,
    ip: str,
) -> CodigoVinculacion:
    """Valida criptográficamente el OTP activo, penaliza intentos fallidos y lo consume."""
    stmt_otp = (
        select(CodigoVinculacion)
        .where(
            CodigoVinculacion.cliente_id == cliente_id,
            CodigoVinculacion.consumido.is_(False),
        )
        .order_by(desc(CodigoVinculacion.created_at))
        .limit(1)
    )
    res_otp = await db.execute(stmt_otp)
    codigo_obj = res_otp.scalar_one_or_none()

    now_utc = datetime.now(UTC)

    if not codigo_obj or codigo_obj.expira_en < now_utc:
        await verify_dummy(password_plano)
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_VINCULACION_ERROR,
        )

    is_valid_otp = verify_otp_hmac(codigo_otp, codigo_obj.codigo_hmac)

    if not is_valid_otp:
        codigo_obj.intentos_fallidos += 1
        if codigo_obj.intentos_fallidos >= 3:
            codigo_obj.consumido = True
        await db.commit()
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_VINCULACION_ERROR,
        )

    codigo_obj.consumido = True
    return codigo_obj


@router.post("/vinculacion", response_model=TokenResponse)
async def vincular_cliente(
    body: VinculacionRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Flujo de vinculación móvil para clientes asegurados."""
    ip = get_client_ip(request)
    cedula = body.cedula.strip()

    await rate_limiter.check_all(ip=ip, identity=cedula, endpoint="vinculacion")

    stmt_cliente = select(Cliente).where(Cliente.identificacion == cedula)
    res_cliente = await db.execute(stmt_cliente)
    cliente = res_cliente.scalar_one_or_none()

    if not cliente:
        await verify_dummy(body.password)
        verify_dummy_otp(body.codigo_otp)
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_VINCULACION_ERROR,
        )

    if cliente.usuario_id is not None:
        await verify_dummy(body.password)
        verify_dummy_otp(body.codigo_otp)
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El cliente ya se encuentra vinculado a una cuenta de usuario.",
        )

    target_email = body.email_opcional or cliente.email
    if not target_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe proporcionar un correo electrónico para completar la vinculación.",
        )
    target_email = target_email.strip().lower()

    stmt_email_check = select(Usuario).where(Usuario.email == target_email)
    res_email_check = await db.execute(stmt_email_check)
    existing_user_email = res_email_check.scalar_one_or_none()

    if existing_user_email is not None:
        rate_limiter.record_failure(identity=cedula, ip=ip)
        raise EmailDuplicadoException("El correo electrónico ya se encuentra registrado")

    await _validar_y_consumir_otp_vinculacion(
        db=db,
        cliente_id=cliente.id,
        codigo_otp=body.codigo_otp,
        password_plano=body.password,
        cedula=cedula,
        ip=ip,
    )

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

    access_token, refresh_token = await emitir_sesion(db, nuevo_usuario)
    await db.commit()

    logger.info("vinculacion_exitosa cliente_id=%s usuario_id=%s", cliente.id, nuevo_usuario.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": str(nuevo_usuario.id),
            "email": nuevo_usuario.email,
            "nombre": nuevo_usuario.nombre,
            "rol": nuevo_usuario.rol.value,
            "activo": nuevo_usuario.activo,
        },
    )

