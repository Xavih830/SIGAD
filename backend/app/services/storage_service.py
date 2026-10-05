"""Storage service — secure physical file persistence with Anti-IDOR controls."""

import hashlib
import io
from pathlib import Path
import re
import uuid

import pypdfium2 as pdfium

from app.core.config import settings

from app.core.constants import (
    MAX_DOCUMENT_SIZE_BYTES,
    MAX_IMAGE_DIMENSION_PX,
    MAX_IMAGE_PIXELS,
    MAX_PDF_PAGES_PERMITTED,
    PERMITTED_MIME_TYPES,
)

ALLOWED_MIME_TYPES = set(PERMITTED_MIME_TYPES)
MAX_FILE_SIZE_BYTES = MAX_DOCUMENT_SIZE_BYTES
MAX_PDF_PAGES = MAX_PDF_PAGES_PERMITTED

ALLOWED_EXTENSIONS_BY_MIME: dict[str, set[str]] = {
    "application/pdf": {".pdf"},
    "image/jpeg": {".jpg", ".jpeg"},
    "image/png": {".png"},
    "image/tiff": {".tif", ".tiff"},
}

IMAGE_EXTENSIONS: frozenset[str] = frozenset(
    ext for mime, exts in ALLOWED_EXTENSIONS_BY_MIME.items() if mime.startswith("image/") for ext in exts
)


class StorageException(Exception):
    """Base storage exception."""
    pass


class StorageSizeLimitException(StorageException):
    """Raised when file exceeds 15 MB limit."""
    pass


class InvalidMimeTypeException(StorageException):
    """Raised when MIME type is not permitted."""
    pass


class MaxPagesExceededException(StorageException):
    """Raised when PDF exceeds 10 pages limit."""
    pass


class StorageSecurityException(StorageException):
    """Raised when path traversal or unauthorized path access is detected."""
    pass


class ImageDimensionsExceededException(StorageSecurityException):
    """Raised when image resolution exceeds permitted dimensions (Anti-Pixel-Flood)."""
    pass


class StorageService:
    """Encapsulates safe file operations with path sanitization and strict validation."""

    def __init__(self, upload_dir: str | None = None) -> None:
        if upload_dir:
            self.base_dir = Path(upload_dir).resolve()
        else:
            self.base_dir = Path(settings.UPLOAD_DIR).resolve()

    def _ensure_dir(self) -> None:
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def _sanitize_filename(self, filename: str) -> str:
        clean = re.sub(r"[^\w\.\-]", "_", filename.strip())
        return clean or "documento.pdf"

    def _validate_magic_bytes(self, content: bytes, mime_type: str) -> bool:
        """Validate genuine binary signatures (magic bytes) to defeat MIME spoofing (CWE-434)."""
        if len(content) < 4:
            return False
        if mime_type == "application/pdf":
            return b"%PDF-" in content[:1024]
        elif mime_type == "image/jpeg":
            return content.startswith(b"\xff\xd8\xff")
        elif mime_type == "image/png":
            return content.startswith(b"\x89PNG\r\n\x1a\n")
        elif mime_type == "image/tiff":
            return content.startswith(b"II*\x00") or content.startswith(b"MM\x00*")
        return False

    def is_image_file(self, filename: str, content: bytes | None = None) -> bool:
        """Determina de forma canónica si un archivo es una imagen usando extensiones y magic bytes."""
        ext = Path(filename).suffix.lower()
        if ext in IMAGE_EXTENSIONS:
            return True
        if content and len(content) >= 4:
            return any(
                self._validate_magic_bytes(content, mime)
                for mime in ALLOWED_MIME_TYPES
                if mime.startswith("image/")
            )
        return False

    def validate_image_dimensions(self, content: bytes) -> tuple[int, int]:
        """Valida que una imagen no exceda las dimensiones máximas permitidas (Anti-Pixel-Flood).
        
        Returns:
            tuple[width, height]
        Raises:
            ImageDimensionsExceededException: Si width o height > 4096 px o total > 16MP.
            StorageException: Si la imagen está dañada o no se puede leer.
        """
        try:
            from PIL import Image

            with Image.open(io.BytesIO(content)) as img:
                w, h = img.size
                if w > MAX_IMAGE_DIMENSION_PX or h > MAX_IMAGE_DIMENSION_PX:
                    raise ImageDimensionsExceededException(
                        f"Las dimensiones de la imagen ({w}x{h} px) exceden el límite máximo permitido de {MAX_IMAGE_DIMENSION_PX}x{MAX_IMAGE_DIMENSION_PX} px."
                    )
                if (w * h) > MAX_IMAGE_PIXELS:
                    raise ImageDimensionsExceededException(
                        f"La resolución total de la imagen ({w * h} px) excede el límite máximo de {MAX_IMAGE_PIXELS} píxeles."
                    )
                return w, h
        except ImageDimensionsExceededException:
            raise
        except Exception as e:
            raise StorageException(f"El archivo de imagen está dañado o es ilegible: {e}")

    def save_file(
        self,
        content: bytes,
        filename: str,
        mime_type: str,
    ) -> tuple[str, str, int, int]:
        """Save file bytes securely to storage.
        
        Returns:
            tuple[file_path_str, sha256_hex, file_size_bytes, page_count]
        """
        self._ensure_dir()
        size = len(content)
        if size > MAX_FILE_SIZE_BYTES:
            raise StorageSizeLimitException("El archivo excede el tamaño máximo permitido de 15 MB.")

        mime = mime_type.lower()
        if mime not in ALLOWED_MIME_TYPES:
            raise InvalidMimeTypeException(
                f"Tipo MIME '{mime_type}' no admitido. Permitidos: {', '.join(sorted(ALLOWED_MIME_TYPES))}"
            )

        if not self._validate_magic_bytes(content, mime):
            raise InvalidMimeTypeException(
                f"La firma binaria del archivo (magic bytes) no coincide con el tipo MIME declarado '{mime_type}'."
            )

        ext = Path(filename).suffix.lower()
        allowed_exts = ALLOWED_EXTENSIONS_BY_MIME.get(mime, set())
        if ext not in allowed_exts:
            raise InvalidMimeTypeException(
                f"Extensión de archivo '{ext}' incompatible o no permitida para el tipo MIME '{mime_type}'. "
                f"Permitidas: {', '.join(sorted(allowed_exts))}"
            )

        page_count = 1
        if mime == "application/pdf":
            try:
                pdf = pdfium.PdfDocument(io.BytesIO(content))
                page_count = len(pdf)
                pdf.close()
            except Exception as e:
                raise StorageException(f"El archivo PDF está dañado o es ilegible: {e}")

            if page_count > MAX_PDF_PAGES:
                raise MaxPagesExceededException(
                    f"El documento excede el límite de 10 páginas (tiene {page_count} páginas)."
                )
        elif mime in ("image/jpeg", "image/png", "image/tiff"):
            self.validate_image_dimensions(content)

        sha256_hash = hashlib.sha256(content).hexdigest()
        sanitized = self._sanitize_filename(filename)
        unique_name = f"{uuid.uuid4().hex}_{sanitized}"
        target_path = self.base_dir / unique_name

        with open(target_path, "wb") as f:
            f.write(content)

        return str(target_path), sha256_hash, size, page_count

    def get_secure_path(self, file_path_str: str) -> Path:
        """Resolve and verify that a file path is strictly inside the authorized upload directory."""
        path = Path(file_path_str).resolve()
        if not path.is_relative_to(self.base_dir):
            raise StorageSecurityException("Acceso a ruta de almacenamiento no autorizada.")
        if not path.exists() or not path.is_file():
            raise FileNotFoundError("El archivo solicitado no existe en almacenamiento.")
        return path


# Singleton default instance
storage_service = StorageService()
