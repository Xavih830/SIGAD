"""Servicio de gestión de sesiones de autenticación con rotación de refresh tokens.

Invariantes de seguridad:
- Emisión de refresh tokens rotatorios vinculados a un jti único y a una familia de tokens (family_id).
- Detección de reutilización (Token Reuse Detection): si un refresh token revocado es presentado,
  toda la familia de tokens es inmediatamente invalidada para mitigar ataques de secuestro de sesión (RFC 6749 / OAuth 2.0 BCP).
- Hashing de refresh tokens mediante SHA-256 en almacenamiento.
- Mensajes de error unificados (anti-enumeración de sesiones).
"""

import inspect
import logging
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_refresh_token,
)
from app.models.sesion_auth import SesionAuth
from app.models.usuario import Usuario

logger = logging.getLogger("sigad.auth.sesion")

_SESION_INVALIDA_ERROR = "Sesión inválida o expirada."


async def emitir_sesion(
    db: AsyncSession,
    usuario: Usuario,
    family_id: uuid.UUID | None = None,
) -> tuple[str, str]:
    """Emite un par de tokens (access, refresh) y persiste la sesión en la base de datos."""
    if family_id is None:
        family_id = uuid.uuid4()

    jti = str(uuid.uuid4())
    token_data = {
        "sub": str(usuario.id),
        "rol": usuario.rol.value,
        "jti": jti,
        "fid": str(family_id),
    }

    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    now_utc = datetime.now(UTC)
    expira_en = now_utc + timedelta(days=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS)

    sesion = SesionAuth(
        usuario_id=usuario.id,
        family_id=family_id,
        jti=jti,
        refresh_token_hash=hash_refresh_token(refresh_token),
        revocado=False,
        expira_en=expira_en,
        created_at=now_utc,
    )
    add_res = db.add(sesion)
    if inspect.isawaitable(add_res):
        await add_res
    await db.flush()

    return access_token, refresh_token


async def rotar_sesion(
    db: AsyncSession,
    refresh_token: str,
) -> tuple[Usuario, str, str]:
    """Rota un refresh token válido, revocando el token actual y emitiendo un nuevo par en la misma familia.

    Si se detecta reutilización de un token previamente revocado, invalida de inmediato
    todas las sesiones pertenecientes a esa familia (RFC 6749 Section 10.4).
    """
    try:
        payload = decode_token(refresh_token)
    except HTTPException:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_SESION_INVALIDA_ERROR,
        ) from None

    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_SESION_INVALIDA_ERROR,
        )

    jti = payload.get("jti")
    if not jti:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_SESION_INVALIDA_ERROR,
        )

    stmt = select(SesionAuth).where(SesionAuth.jti == str(jti))
    res = await db.execute(stmt)
    sesion = res.scalar_one_or_none()

    now_utc = datetime.now(UTC)

    if sesion is None or sesion.refresh_token_hash != hash_refresh_token(refresh_token) or sesion.expira_en < now_utc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_SESION_INVALIDA_ERROR,
        )

    # Detección de reutilización de refresh token (Token Reuse Attack)
    if sesion.revocado:
        stmt_revoke = (
            update(SesionAuth)
            .where(SesionAuth.family_id == sesion.family_id)
            .values(revocado=True)
        )
        await db.execute(stmt_revoke)
        await db.commit()
        logger.warning("refresh_reuse_detected family_id=%s", sesion.family_id)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_SESION_INVALIDA_ERROR,
        )

    # Revocar sesión actual
    sesion.revocado = True

    # Cargar usuario
    stmt_user = select(Usuario).where(Usuario.id == sesion.usuario_id)
    res_user = await db.execute(stmt_user)
    usuario = res_user.scalar_one_or_none()

    if usuario is None or not usuario.activo:
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_SESION_INVALIDA_ERROR,
        )

    # Emitir nueva sesión preservando la misma familia
    access_token, new_refresh_token = await emitir_sesion(
        db=db,
        usuario=usuario,
        family_id=sesion.family_id,
    )
    await db.commit()
    await db.refresh(usuario)

    return usuario, access_token, new_refresh_token


async def revocar_familia(
    db: AsyncSession,
    refresh_token: str,
) -> None:
    """Revoca todas las sesiones de la familia asociada al token (logout). Es idempotente."""
    try:
        payload = decode_token(refresh_token)
        if payload.get("type") == "refresh":
            fid_str = payload.get("fid")
            if fid_str:
                family_id = uuid.UUID(str(fid_str))
                stmt = (
                    update(SesionAuth)
                    .where(SesionAuth.family_id == family_id)
                    .values(revocado=True)
                )
                await db.execute(stmt)
                await db.commit()
    except (ValueError, KeyError, HTTPException) as e:
        logger.warning("No se pudo revocar familia por token no procesable: %s", e)
