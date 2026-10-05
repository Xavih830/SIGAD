"""Shared FastAPI dependencies — DB session and auth guards."""

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.db.session import get_db
from app.models.usuario import RolEnum, Usuario

security_scheme = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: AsyncSession = Depends(get_db),
) -> Usuario:
    """Extract and validate the current user from the JWT bearer token."""
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("type") != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token no válido para autenticación (tipo no autorizado)",
            )
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")
    except jwt.PyJWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido o expirado")

    result = await db.execute(select(Usuario).where(Usuario.id == user_id))
    user = result.scalar_one_or_none()
    if user is None or not user.activo:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario no encontrado o inactivo")
    return user


def check_role(*allowed_roles: RolEnum):
    """Dependency factory that restricts access to specific roles."""
    async def role_guard(user: Usuario = Depends(get_current_user)) -> Usuario:
        if user.rol not in allowed_roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acceso denegado")
        return user
    return role_guard


def get_client_ip(request: Request) -> str:
    """Extrae la IP real del cliente detrás del proxy inverso (Caddy X-Real-IP)."""
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip.strip()
    return request.client.host if request.client else "127.0.0.1"


async def check_catalog_rate_limit(request: Request) -> None:
    """Guardián de rate limiting por IP para catálogos públicos sin autenticación."""
    from app.core.rate_limit import rate_limiter

    ip = get_client_ip(request)
    rate_limiter.check_ip(ip=ip, endpoint="catalogo")

