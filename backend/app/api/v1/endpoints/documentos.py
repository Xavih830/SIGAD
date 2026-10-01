"""Documentos REST API — canonical single ingress, status retrieval, and Anti-IDOR authorized downloads."""

import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.orm.attributes import flag_modified

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.documento import Documento, EstadoExtraccionEnum
from app.models.poliza import Poliza
from app.models.usuario import RolEnum, Usuario
from app.schemas.documento import (
    DocumentoListItemResponse,
    DocumentoResponse,
    DocumentoRevisionRequest,
    DocumentoRevisionResponse,
    ResultadoExtraccionResponse,
)
from app.core.constants import MAX_DOCUMENT_SIZE_BYTES
from app.services.storage_service import (
    InvalidMimeTypeException,
    MaxPagesExceededException,
    StorageSecurityException,
    StorageSizeLimitException,
    storage_service,
)

router = APIRouter(prefix="/documentos", tags=["Documentos"])


def _verificar_acceso_documento(doc: Documento | None, poliza: Poliza | None, current_user: Usuario) -> None:
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


@router.post("", response_model=DocumentoResponse, status_code=status.HTTP_201_CREATED)
async def cargar_documento(
    file: UploadFile = File(...),
    poliza_id: uuid.UUID | None = Form(None),
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DocumentoResponse:
    """Canonical Single Ingress endpoint for document upload with 15MB limit and <=10 page validation."""
    if not file.filename or not file.filename.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El nombre de archivo es obligatorio y no puede estar vacío.",
        )

    if not file.content_type or not file.content_type.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="La cabecera Content-Type es obligatoria.",
        )

    content = await file.read()

    # Pre-check tamaño máximo
    if len(content) > MAX_DOCUMENT_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="El archivo excede el tamaño máximo permitido de 15 MB.",
        )

    # Validar acceso a la póliza si se envía poliza_id
    poliza = None
    if poliza_id:
        p_res = await db.execute(
            select(Poliza).options(selectinload(Poliza.cliente)).where(Poliza.id == poliza_id)
        )
        poliza = p_res.scalar_one_or_none()
        if not poliza:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Póliza no encontrada.")
        _verificar_acceso_documento(None, poliza, current_user)

    try:
        ruta_archivo, sha256_hash, tamano, paginas = storage_service.save_file(
            content=content,
            filename=file.filename.strip(),
            mime_type=file.content_type.strip(),
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
        nombre_archivo=file.filename.strip(),
        ruta_archivo=ruta_archivo,
        tipo_mime=file.content_type.strip(),
        tamano_bytes=tamano,
        hash_sha256=sha256_hash,
        estado_extraccion=EstadoExtraccionEnum.PENDIENTE.value,
        intentos=0,
    )
    db.add(documento)
    await db.commit()
    await db.refresh(documento)

    return DocumentoResponse(
        id=documento.id,
        poliza_id=documento.poliza_id,
        nombre_archivo=documento.nombre_archivo,
        tipo_mime=documento.tipo_mime,
        tamano_bytes=documento.tamano_bytes,
        hash_sha256=documento.hash_sha256,
        estado_extraccion=documento.estado_extraccion,
        intentos=documento.intentos,
        paginas=paginas,
        created_at=documento.created_at,
        updated_at=documento.updated_at,
    )


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


@router.get("/{documento_id}", response_model=DocumentoResponse)
async def obtener_documento(
    documento_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DocumentoResponse:
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

    resultado_dto = None
    if doc.resultado:
        resultado_dto = ResultadoExtraccionResponse(
            metodo=doc.resultado.metodo,
            confianza=float(doc.resultado.confianza),
            texto_completo=doc.resultado.texto_completo,
            campos_extraidos=doc.resultado.campos_extraidos,
        )

    return DocumentoResponse(
        id=doc.id,
        poliza_id=doc.poliza_id,
        nombre_archivo=doc.nombre_archivo,
        tipo_mime=doc.tipo_mime,
        tamano_bytes=doc.tamano_bytes,
        hash_sha256=doc.hash_sha256,
        estado_extraccion=doc.estado_extraccion,
        intentos=doc.intentos,
        error_motivo=doc.error_motivo,
        created_at=doc.created_at,
        updated_at=doc.updated_at,
        resultado=resultado_dto,
    )


@router.get("", response_model=list[DocumentoListItemResponse])
async def listar_documentos(
    poliza_id: uuid.UUID | None = None,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[DocumentoListItemResponse]:
    """List documents accessible to current user."""
    stmt = select(Documento).options(
        selectinload(Documento.poliza).selectinload(Poliza.cliente),
        selectinload(Documento.resultado),
    ).order_by(Documento.created_at.desc())

    if poliza_id:
        stmt = stmt.where(Documento.poliza_id == poliza_id)

    res = await db.execute(stmt)
    docs = res.scalars().all()

    items: list[DocumentoListItemResponse] = []
    for doc in docs:
        if current_user.rol != RolEnum.ADMIN:
            if doc.poliza is None or doc.poliza.cliente is None or doc.poliza.cliente.usuario_id != current_user.id:
                continue

        items.append(
            DocumentoListItemResponse(
                id=doc.id,
                poliza_id=doc.poliza_id,
                nombre_archivo=doc.nombre_archivo,
                tipo_mime=doc.tipo_mime,
                tamano_bytes=doc.tamano_bytes,
                estado_extraccion=doc.estado_extraccion,
                has_resultado=doc.resultado is not None,
                created_at=doc.created_at,
            )
        )

    return items


@router.patch("/{documento_id}/revision", response_model=DocumentoRevisionResponse, status_code=status.HTTP_200_OK)
async def revisar_campos_documento(
    documento_id: uuid.UUID,
    payload: DocumentoRevisionRequest,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DocumentoRevisionResponse:
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

    return DocumentoRevisionResponse(
        id=doc.id,
        estado_extraccion=doc.estado_extraccion,
        campos_extraidos=doc.resultado.campos_extraidos,
        updated_at=doc.updated_at,
    )
