"""Unit tests for Ecuadorian ANT License Plate Validation (Section 11.2).

Verification Gate 2: Particiones de equivalencia de placas ANT.
Validates:
  - Particular (3L+4D): PBA-1234
  - Moto (2L+4D): AB-1234
  - Moto ANT actual (2L+3D+1L): AB-123C
  - Servicio público (3L+4D): PTA-1234
Rejects:
  - Formato antiguo (3L+3D): XYZ-123
  - Invertido: 1234-ABC
  - Caracteres especiales / espacios: AB C-123
  - Sin guión o minúsculas no normalizadas: PBA1234, pba-1234
"""

import pytest

from app.schemas.vehiculo import validar_placa_ecuador


@pytest.mark.parametrize(
    "placa,descripcion",
    [
        ("PBA-1234", "Particular 3L+4D"),
        ("GYE-0987", "Particular Guayas 3L+4D"),
        ("AB-1234", "Moto estándar 2L+4D"),
        ("AB-123C", "Moto alfanumérica ANT actual 2L+3D+1L"),
        ("PTA-1234", "Servicio público Pichincha 3L+4D"),
        ("IAA-5678", "Particular Imbabura"),
        ("UAA-1111", "Particular Sucumbíos"),
    ],
)
def test_placas_ant_validas(placa: str, descripcion: str):
    """Valida particiones de equivalencia válidas según Sección 11.2."""
    assert validar_placa_ecuador(placa) is True, f"Falló placa válida ({descripcion}): {placa}"


@pytest.mark.parametrize(
    "placa,motivo",
    [
        ("XYZ-123", "Formato antiguo descontinuado 3L+3D"),
        ("1234-ABC", "Orden invertido"),
        ("AB C-123", "Espacio intermedio y 3 dígitos"),
        ("PBA 1234", "Espacio en lugar de guión"),
        ("PBA1234", "Sin guión"),
        ("PBA-12345", "5 dígitos en auto"),
        ("PBA-123", "3 dígitos en auto"),
        ("A-1234", "Solo 1 letra"),
        ("ABCD-1234", "4 letras"),
        ("AB-12C", "Moto alfanumérica con 2 dígitos en vez de 3"),
        ("AB-1234C", "Moto alfanumérica con 4 dígitos y letra"),
        ("pba-1234", "Minúsculas no permitidas"),
        ("", "Cadena vacía"),
        ("   ", "Solo espacios"),
        ("PBA-123A", "Auto con letra al final no permitido"),
    ],
)
def test_placas_ant_invalidas(placa: str, motivo: str):
    """Rechaza particiones inválidas según Sección 11.2."""
    assert validar_placa_ecuador(placa) is False, f"Se debió rechazar ({motivo}): {placa}"
