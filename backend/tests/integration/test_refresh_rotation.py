"""Pruebas de integración para rotación de sesiones y refresh tokens con detección de reuso."""

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sesion_auth import SesionAuth
from tests.factories.fixtures import CLIENTE_PASSWORD
from tests.factories.models import create_user

pytestmark = pytest.mark.asyncio(loop_scope="session")


async def test_login_crea_exactamente_una_sesion(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Verifica que un login exitoso registre exactamente una fila en sesiones_auth."""
    user = await create_user(db_session, email="login_sesion@sigad.ec")

    res = await client.post(
        "/api/v1/auth/login",
        json={"identificador": user.email, "password": CLIENTE_PASSWORD},
    )
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    assert "refresh_token" in data

    stmt = select(func.count()).select_from(SesionAuth).where(SesionAuth.usuario_id == user.id)
    count = await db_session.scalar(stmt)
    assert count == 1

    sesion = (await db_session.execute(select(SesionAuth).where(SesionAuth.usuario_id == user.id))).scalar_one()
    assert sesion.revocado is False
    assert sesion.expira_en is not None


async def test_refresh_valido_rota_token_y_conserva_familia(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Verifica que un refresh válido devuelva nuevos tokens con distinto jti, revoque el anterior y mantenga family_id."""
    user = await create_user(db_session, email="refresh_valid@sigad.ec")

    login_res = await client.post(
        "/api/v1/auth/login",
        json={"identificador": user.email, "password": CLIENTE_PASSWORD},
    )
    assert login_res.status_code == 200
    initial_refresh = login_res.json()["refresh_token"]

    stmt_initial = select(SesionAuth).where(SesionAuth.usuario_id == user.id)
    initial_sesion = (await db_session.execute(stmt_initial)).scalar_one()
    initial_jti = initial_sesion.jti
    family_id = initial_sesion.family_id

    refresh_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": initial_refresh},
    )
    assert refresh_res.status_code == 200
    new_data = refresh_res.json()
    assert "access_token" in new_data
    assert "refresh_token" in new_data
    assert new_data["refresh_token"] != initial_refresh

    await db_session.refresh(initial_sesion)
    assert initial_sesion.revocado is True

    # Comprobar que existe la nueva sesión activa con el mismo family_id y distinto jti
    stmt_active = select(SesionAuth).where(
        SesionAuth.usuario_id == user.id,
        SesionAuth.revocado.is_(False),
    )
    active_sesion = (await db_session.execute(stmt_active)).scalar_one()
    assert active_sesion.family_id == family_id
    assert active_sesion.jti != initial_jti


async def test_reutilizacion_refresh_revoca_toda_la_familia(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Verifica que reutilizar un refresh ya rotado resulte en 401 e invalide toda la familia."""
    user = await create_user(db_session, email="reuse_attack@sigad.ec")

    # 1. Login inicial
    login_res = await client.post(
        "/api/v1/auth/login",
        json={"identificador": user.email, "password": CLIENTE_PASSWORD},
    )
    old_refresh = login_res.json()["refresh_token"]

    # 2. Primera rotación legítima
    rot1_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh},
    )
    assert rot1_res.status_code == 200
    legit_refresh = rot1_res.json()["refresh_token"]

    # 3. Ataque de reutilización: volver a usar old_refresh
    attack_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh},
    )
    assert attack_res.status_code == 401
    assert attack_res.json()["detail"] == "Sesión inválida o expirada."

    # 4. Verificar que toda la familia quedó revocada (el token legítimo ahora también debe fallar)
    subsequent_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": legit_refresh},
    )
    assert subsequent_res.status_code == 401
    assert subsequent_res.json()["detail"] == "Sesión inválida o expirada."

    # Verificar en BD que no quedan sesiones activas para este usuario
    stmt_active = select(func.count()).select_from(SesionAuth).where(
        SesionAuth.usuario_id == user.id,
        SesionAuth.revocado.is_(False),
    )
    active_count = await db_session.scalar(stmt_active)
    assert active_count == 0


async def test_access_token_en_endpoint_refresh_retorna_401(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Verifica que enviar un access_token al endpoint /auth/refresh sea rechazado con 401."""
    user = await create_user(db_session, email="wrong_token_type@sigad.ec")

    login_res = await client.post(
        "/api/v1/auth/login",
        json={"identificador": user.email, "password": CLIENTE_PASSWORD},
    )
    access_token = login_res.json()["access_token"]

    res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": access_token},
    )
    assert res.status_code == 401
    assert res.json()["detail"] == "Sesión inválida o expirada."


async def test_logout_revoca_familia_y_refresh_posterior_falla(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Verifica que /auth/logout revoque la familia y que un refresh posterior devuelva 401."""
    user = await create_user(db_session, email="logout_test@sigad.ec")

    login_res = await client.post(
        "/api/v1/auth/login",
        json={"identificador": user.email, "password": CLIENTE_PASSWORD},
    )
    refresh_token = login_res.json()["refresh_token"]

    logout_res = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_token},
    )
    assert logout_res.status_code == 204

    # Refresh posterior debe fallar
    refresh_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh_res.status_code == 401
    assert refresh_res.json()["detail"] == "Sesión inválida o expirada."
