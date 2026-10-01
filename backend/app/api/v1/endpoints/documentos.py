"""Documentos REST API — upload, status retrieval, and Anti-IDOR authorized downloads."""

import uuid
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.orm.attributes import flag_modified

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.cliente import Cliente
from app.models.documento import Documento, EstadoExtraccionEnum
from app.models.poliza import Poliza
from app.models.resultado_extraccion import ResultadoExtraccion
from app.models.usuario import RolEnum, Usuario
from app.schemas.documento import DocumentoRevisionRequest
from app.services.storage_service import (
    InvalidMimeTypeException,
    MaxPagesExceededException,
    StorageSecurityException,
    StorageSizeLimitException,
    storage_service,
)

router = APIRouter(prefix="/documentos", tags=["Documentos"])


def _verificar_acceso_documento(doc: Documento, poliza: Poliza | None, current_user: Usuario) -> None:
    """Enforces Anti-IDOR access control.
    
    Admins have full access.
    Clients can only access documents associated with their own policies.
    """
    if current_user.rol == RolEnum.ADMIN:
        return

    if poliza is None or poliza.cliente is None or poliza.cliente.usuario_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso denegado: no tiene permisos para este documento.",
        )


@router.post("/cargar", status_code=status.HTTP_201_CREATED)
@router.post("", status_code=status.HTTP_201_CREATED)
async def cargar_documento(
    file: UploadFile = File(...),
    poliza_id: uuid.UUID | None = Form(None),
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Uploads a document (PDF or image) with 15MB limit and <=10 page validation."""
    content = await file.read()

    # Pre-check size to return 413 immediately
    if len(content) > 15 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="El archivo excede el tamaño máximo permitido de 15 MB.",
        )

    # Validate policy if provided
    poliza = None
    if poliza_id:
        p_res = await db.execute(
            select(Poliza).options(selectinload(Poliza.cliente)).where(Poliza.id == poliza_id)
        )
        poliza = p_res.scalar_one_or_none()
        if not poliza:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Póliza no encontrada.")
        _verificar_acceso_documento(None, poliza, current_user)

    mime_type = file.content_type or "application/octet-stream"

    try:
        ruta_archivo, sha256_hash, tamano, paginas = storage_service.save_file(
            content=content,
            filename=file.filename or "documento.pdf",
            mime_type=mime_type,
        )
    except StorageSizeLimitException as e:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail=str(e))
    except (InvalidMimeTypeException, MaxPagesExceededException) as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Error al procesar archivo: {e}")

    documento = Documento(
        id=uuid.uuid4(),
        poliza_id=poliza_id,
        nombre_archivo=file.filename or "documento.pdf",
        ruta_archivo=ruta_archivo,
        tipo_mime=mime_type,
        tamano_bytes=tamano,
        hash_sha256=sha256_hash,
        estado_extraccion=EstadoExtraccionEnum.PENDIENTE.value,
        intentos=0,
    )
    db.add(documento)
    await db.commit()
    await db.refresh(documento)

    return {
        "id": str(documento.id),
        "poliza_id": str(documento.poliza_id) if documento.poliza_id else None,
        "nombre_archivo": documento.nombre_archivo,
        "tipo_mime": documento.tipo_mime,
        "tamano_bytes": documento.tamano_bytes,
        "hash_sha256": documento.hash_sha256,
        "estado_extraccion": documento.estado_extraccion,
        "paginas": paginas,
        "created_at": documento.created_at.isoformat(),
    }


@router.get("/{documento_id}/descargar")
async def descargar_documento(
    documento_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> FileResponse:
    """Anti-IDOR authorized download endpoint."""
    stmt = (
        select(Documento)
        .options(
            selectinload(Documento.poliza).selectinload(Poliza.cliente)
        )
        .where(Documento.id == documento_id)
    )
    res = await db.execute(stmt)
    doc = res.scalar_one_or_none()

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Documento no encontrado.")

    _verificar_acceso_documento(doc, doc.poliza, current_user)

    try:
        secure_path = storage_service.get_secure_path(doc.ruta_archivo)
    except (StorageSecurityException, FileNotFoundError) as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    return FileResponse(
        path=secure_path,
        media_type=doc.tipo_mime,
        filename=doc.nombre_archivo,
    )


@router.get("/{documento_id}")
async def obtener_documento(
    documento_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Retrieves document processing status and extracted results."""
    stmt = (
        select(Documento)
        .options(
            selectinload(Documento.poliza).selectinload(Poliza.cliente),
            selectinload(Documento.resultado),
        )
        .where(Documento.id == documento_id)
    )
    res = await db.execute(stmt)
    doc = res.scalar_one_or_none()

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Documento no encontrado.")

    _verificar_acceso_documento(doc, doc.poliza, current_user)

    data: dict[str, Any] = {
        "id": str(doc.id),
        "poliza_id": str(doc.poliza_id) if doc.poliza_id else None,
        "nombre_archivo": doc.nombre_archivo,
        "tipo_mime": doc.tipo_mime,
        "tamano_bytes": doc.tamano_bytes,
        "estado_extraccion": doc.estado_extraccion,
        "intentos": doc.intentos,
        "error_motivo": doc.error_motivo,
        "created_at": doc.created_at.isoformat(),
        "updated_at": doc.updated_at.isoformat(),
        "resultado": None,
    }

    if doc.resultado:
        data["resultado"] = {
            "metodo": doc.resultado.metodo,
            "confianza": float(doc.resultado.confianza),
            "texto_completo": doc.resultado.texto_completo,
            "campos_extraidos": doc.resultado.campos_extraidos,
        }

    return data


@router.get("")
async def listar_documentos(
    poliza_id: uuid.UUID | None = None,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict[str, Any]]:
    """List documents accessible to current user."""
    stmt = select(Documento).options(
        selectinload(Documento.poliza).selectinload(Poliza.cliente),
        selectinload(Documento.resultado),
    ).order_by(Documento.created_at.desc())

    if poliza_id:
        stmt = stmt.where(Documento.poliza_id == poliza_id)

    res = await db.execute(stmt)
    docs = res.scalars().all()

    items = []
    for doc in docs:
        if current_user.rol != RolEnum.ADMIN:
            if doc.poliza is None or doc.poliza.cliente is None or doc.poliza.cliente.usuario_id != current_user.id:
                continue

        items.append({
            "id": str(doc.id),
            "poliza_id": str(doc.poliza_id) if doc.poliza_id else None,
            "nombre_archivo": doc.nombre_archivo,
            "tipo_mime": doc.tipo_mime,
            "tamano_bytes": doc.tamano_bytes,
            "estado_extraccion": doc.estado_extraccion,
            "has_resultado": doc.resultado is not None,
            "created_at": doc.created_at.isoformat(),
        })

    return items


@router.patch("/{documento_id}/revision", status_code=status.HTTP_200_OK)
async def revisar_campos_documento(
    documento_id: uuid.UUID,
    payload: DocumentoRevisionRequest,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Allows Agents and Admins to correct and confirm OCR extracted fields (HU-06)."""
    if current_user.rol not in [RolEnum.ADMIN, RolEnum.AGENTE]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores y agentes pueden revisar documentos.",
        )

    stmt = (
        select(Documento)
        .options(selectinload(Documento.resultado))
        .where(Documento.id == documento_id)
    )
    res = await db.execute(stmt)
    doc = res.scalar_one_or_none()

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Documento no encontrado.")

    if not doc.resultado:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El documento no posee resultados de extracción para revisar.",
        )

    # Actualizar campos JSONB
    doc.resultado.campos_extraidos = dict(payload.campos_extraidos)
    flag_modified(doc.resultado, "campos_extraidos")

    # Actualizar estado si fue enviado
    if payload.estado_extraccion:
        if payload.estado_extraccion not in [
            EstadoExtraccionEnum.COMPLETADO.value,
            EstadoExtraccionEnum.REQUIERE_REVISION_MANUAL.value,
        ]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Estado de extracción inválido: {payload.estado_extraccion}",
            )
        doc.estado_extraccion = payload.estado_extraccion

    await db.commit()
    await db.refresh(doc)
    await db.refresh(doc.resultado)

    return {
        "id": str(doc.id),
        "estado_extraccion": doc.estado_extraccion,
        "campos_extraidos": doc.resultado.campos_extraidos,
        "updated_at": doc.updated_at.isoformat(),
    }
