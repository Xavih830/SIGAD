"""Unit tests for image dimension validation (Anti-Pixel-Flood & Decompression Bombs)."""

import io
from PIL import Image
import pytest

from app.services.storage_service import (
    ImageDimensionsExceededException,
    StorageException,
    storage_service,
)


def _crear_imagen_bytes(ancho: int, alto: int, formato: str = "PNG") -> bytes:
    """Crea una imagen sintética en memoria sin contenido pesado."""
    img = Image.new("RGB", (ancho, alto), color="white")
    buf = io.BytesIO()
    img.save(buf, format=formato)
    return buf.getvalue()


def test_imagen_dimensiones_validas_retorna_tupla():
    """Una imagen dentro de los límites (<= 4096 px y <= 16MP) es aprobada correctamente."""
    img_bytes = _crear_imagen_bytes(800, 600)
    w, h = storage_service.validate_image_dimensions(img_bytes)
    assert w == 800
    assert h == 600


def test_imagen_ancho_excedido_lanza_excepcion():
    """Una imagen con ancho > 4096 px debe ser rechazada inmediatamente."""
    img_bytes = _crear_imagen_bytes(5000, 100)
    with pytest.raises(ImageDimensionsExceededException, match="exceden el límite máximo permitido"):
        storage_service.validate_image_dimensions(img_bytes)


def test_imagen_alto_excedido_lanza_excepcion():
    """Una imagen con alto > 4096 px debe ser rechazada inmediatamente."""
    img_bytes = _crear_imagen_bytes(100, 5000)
    with pytest.raises(ImageDimensionsExceededException, match="exceden el límite máximo permitido"):
        storage_service.validate_image_dimensions(img_bytes)


def test_imagen_resolucion_total_excedida_lanza_excepcion():
    """Una imagen de 4096 x 4000 px (16.38 MP > 16 MP) debe ser rechazada por resolución total."""
    img_bytes = _crear_imagen_bytes(4096, 4000)
    with pytest.raises(ImageDimensionsExceededException, match="excede el límite máximo de 16000000 píxeles"):
        storage_service.validate_image_dimensions(img_bytes)


def test_imagen_bytes_corruptos_lanza_storage_exception():
    """Bytes corruptos no válidos como imagen deben lanzar StorageException."""
    corrupt_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\x00CORRUPT_DATA"
    with pytest.raises(StorageException, match="dañado o es ilegible"):
        storage_service.validate_image_dimensions(corrupt_bytes)
