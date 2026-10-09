"""Esquemas de extracción configurables — Endpoints de administración y testing."""

import os
from pathlib import Path
import tempfile
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_role
from app.core.constants import MAX_DOCUMENT_SIZE_BYTES
from app.db.session import get_db
from app.models.esquema_extraccion import EsquemaExtraccion
from app.models.usuario import RolEnum, Usuario
from app.schemas.esquema_extraccion import (
    EsquemaCreate,
    EsquemaListItem,
    EsquemaResponse,
    ProbarEsquemaResponse,
)
from app.services.extraccion_service import aplicar_esquema, extraer_documento_sync
from app.services.storage_service import (
    ImageDimensionsExceededException,
    StorageException,
    storage_service,
)

router = APIRouter(prefix="/esquemas", tags=["Esquemas de Extracción"])


@router.get("", response_model=list[EsquemaListItem])
async def listar_esquemas(
    _: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> list[EsquemaExtraccion]:
    """Lista todos los esquemas (todas las versiones). Solo ADMIN y AGENTE."""
    res = await db.execute(
        select(EsquemaExtraccion).order_by(
            EsquemaExtraccion.codigo,
            EsquemaExtraccion.version.desc(),
        )
    )
    return list(res.scalars().all())


@router.get("/{esquema_id}", response_model=EsquemaResponse)
async def obtener_esquema(
    esquema_id: uuid.UUID,
    _: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> EsquemaExtraccion:
    """Detalle de un esquema con sus campos. Solo ADMIN y AGENTE."""
    res = await db.execute(
        select(EsquemaExtraccion).where(EsquemaExtraccion.id == esquema_id)
    )
    esquema = res.scalar_one_or_none()
    if not esquema:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Esquema no encontrado.",
        )
    return esquema


@router.post("", response_model=EsquemaResponse, status_code=status.HTTP_201_CREATED)
async def crear_esquema(
    payload: EsquemaCreate,
    current_user: Usuario = Depends(check_role(RolEnum.ADMIN)),
    db: AsyncSession = Depends(get_db),
) -> EsquemaExtraccion:
    """Crea una nueva versión del esquema (append-only).

    - Si el `codigo` no existe, crea versión 1.
    - Si ya existe, incrementa la versión. La versión nueva empieza inactiva.
    """
    max_res = await db.execute(
        select(func.max(EsquemaExtraccion.version))
        .where(EsquemaExtraccion.codigo == payload.codigo)
    )
    nueva_version = (max_res.scalar() or 0) + 1

    esquema = EsquemaExtraccion(
        codigo=payload.codigo,
        nombre=payload.nombre,
        descripcion=payload.descripcion,
        version=nueva_version,
        es_activo=False,
        creado_por=current_user.id,
        campos=[c.model_dump() for c in payload.campos],
    )
    db.add(esquema)
    await db.commit()
    await db.refresh(esquema)
    return esquema


@router.patch("/{esquema_id}/activar", response_model=EsquemaResponse)
async def activar_esquema(
    esquema_id: uuid.UUID,
    _: Usuario = Depends(check_role(RolEnum.ADMIN)),
    db: AsyncSession = Depends(get_db),
) -> EsquemaExtraccion:
    """Activa una versión y desactiva las demás del mismo codigo.

    Sin body — previene over-posting (OWASP API3).
    Operación atómica: desactivación masiva + activación en la misma transacción.
    """
    res = await db.execute(
        select(EsquemaExtraccion).where(EsquemaExtraccion.id == esquema_id)
    )
    esquema = res.scalar_one_or_none()
    if not esquema:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Esquema no encontrado.",
        )

    await db.execute(
        update(EsquemaExtraccion)
        .where(
            EsquemaExtraccion.codigo == esquema.codigo,
            EsquemaExtraccion.id != esquema_id,
        )
        .values(es_activo=False)
    )
    esquema.es_activo = True
    await db.commit()
    await db.refresh(esquema)
    return esquema


@router.post("/{esquema_id}/probar", response_model=ProbarEsquemaResponse)
async def probar_esquema(
    esquema_id: uuid.UUID,
    file: UploadFile = File(...),
    _: Usuario = Depends(check_role(RolEnum.ADMIN, RolEnum.AGENTE)),
    db: AsyncSession = Depends(get_db),
) -> ProbarEsquemaResponse:
    """Aplica el esquema a un archivo sin persistir ningún resultado.

    Permite verificar reglas regex antes de activar la versión.
    Límite: mismo MAX_DOCUMENT_SIZE_BYTES que el endpoint /documentos.
    """
    res = await db.execute(
        select(EsquemaExtraccion).where(EsquemaExtraccion.id == esquema_id)
    )
    esquema = res.scalar_one_or_none()
    if not esquema:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Esquema no encontrado.",
        )

    content = await file.read()
    if len(content) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo proporcionado está vacío.",
        )

    if len(content) > MAX_DOCUMENT_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Archivo demasiado grande para prueba.",
        )

    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El nombre de archivo es obligatorio.",
        )
    filename = file.filename.strip()
    suffix = Path(filename).suffix.lower()
    if not suffix:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo debe tener una extensión válida.",
        )

    if storage_service.is_image_file(filename, content):
        try:
            storage_service.validate_image_dimensions(content)
        except (ImageDimensionsExceededException, StorageException) as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(e),
            )

    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(content)
        tmp_path = tmp.name

    try:
        resultado = extraer_documento_sync(tmp_path, campos_esquema=esquema.campos)
        campos_extraidos = resultado["campos_extraidos"]
        confianza = float(resultado["confianza"])
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Error durante el procesamiento del documento: {exc}",
        ) from exc
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)  # Siempre eliminar el temporal (OWASP API9)

    return ProbarEsquemaResponse(
        metodo=resultado["metodo"],
        confianza=confianza,
        campos_extraidos=campos_extraidos,
        texto_completo=resultado["texto_completo"],
    )
