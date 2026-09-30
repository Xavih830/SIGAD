"""Storage service — secure physical file persistence with Anti-IDOR controls."""

import hashlib
import io
import os
from pathlib import Path
import re
import uuid

import pypdfium2 as pdfium

ALLOWED_MIME_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/tiff",
}

MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024  # 15 MB = 15,728,640 bytes
MAX_PDF_PAGES = 10


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


class StorageService:
    """Encapsulates safe file operations with path sanitization and strict validation."""

    def __init__(self, upload_dir: str | None = None) -> None:
        if upload_dir:
            self.base_dir = Path(upload_dir).resolve()
        else:
            env_dir = os.getenv("SIGAD_UPLOAD_DIR")
            if env_dir:
                self.base_dir = Path(env_dir).resolve()
            elif os.path.exists("/app") and os.access("/app", os.W_OK):
                self.base_dir = Path("/app/uploads").resolve()
            else:
                # Local fallback inside project directory
                project_root = Path(__file__).resolve().parent.parent.parent
                self.base_dir = (project_root / "uploads").resolve()

        self.base_dir.mkdir(parents=True, exist_ok=True)

    def _sanitize_filename(self, filename: str) -> str:
        clean = re.sub(r"[^\w\.\-]", "_", filename.strip())
        return clean or "documento.pdf"

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
        size = len(content)
        if size > MAX_FILE_SIZE_BYTES:
            raise StorageSizeLimitException("El archivo excede el tamaño máximo permitido de 15 MB.")

        if mime_type.lower() not in ALLOWED_MIME_TYPES:
            raise InvalidMimeTypeException(
                f"Tipo MIME '{mime_type}' no admitido. Permitidos: {', '.join(sorted(ALLOWED_MIME_TYPES))}"
            )

        page_count = 1
        if mime_type.lower() == "application/pdf":
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
