"""Pruebas unitarias para la validación y clasificación de placas vehiculares ecuatorianas (ANT).

Cubre particiones de equivalencia y valores frontera según la Decisión D5:
- Particular: 3 letras, segunda letra distinta de {A, U, Z, E, X, M, S}.
- Servicio público: 3 letras, segunda letra en {A, U, Z}.
- Gubernamental / oficial: 3 letras, segunda letra en {E, X, M, S}.
- Moto: 2 letras (formatos 2L+4D y 2L+3D+1L).
"""

import pytest

from app.schemas.vehiculo import (
    TipoPlacaEnum,
    clasificar_placa,
    validar_placa_ecuador,
)


@pytest.mark.parametrize(
    "placa,tipo_esperado,descripcion",
    [
        # Particular
        ("PBA-1234", TipoPlacaEnum.PARTICULAR, "Particular Pichincha 3L+4D"),
        ("GYE-0987", TipoPlacaEnum.PARTICULAR, "Particular Guayas 3L+4D"),
        ("ICA-0001", TipoPlacaEnum.PARTICULAR, "Particular Imbabura 3L+4D"),
        ("PTA-1234", TipoPlacaEnum.PARTICULAR, "Particular Pichincha segunda letra T (D5)"),
        ("IAA-5678", TipoPlacaEnum.SERVICIO_PUBLICO, "Servicio público Imbabura segunda letra A"),
        ("UAA-1111", TipoPlacaEnum.SERVICIO_PUBLICO, "Servicio público Sucumbíos segunda letra A"),
        # Moto
        ("AB-1234", TipoPlacaEnum.MOTO, "Moto estándar 2L+4D"),
        ("AB-123C", TipoPlacaEnum.MOTO, "Moto alfanumérica ANT actual 2L+3D+1L"),
        # Servicio Público
        ("GAA-1234", TipoPlacaEnum.SERVICIO_PUBLICO, "Servicio público Guayas segunda letra A"),
        ("PUB-0001", TipoPlacaEnum.SERVICIO_PUBLICO, "Servicio público Pichincha segunda letra U"),
        ("PZA-9999", TipoPlacaEnum.SERVICIO_PUBLICO, "Servicio público Pichincha segunda letra Z"),
        # Gubernamental
        ("PEA-1234", TipoPlacaEnum.GUBERNAMENTAL, "Gubernamental Pichincha segunda letra E"),
        ("PXA-1234", TipoPlacaEnum.GUBERNAMENTAL, "Gubernamental Pichincha segunda letra X"),
        ("PMA-0001", TipoPlacaEnum.GUBERNAMENTAL, "Gubernamental Pichincha segunda letra M"),
        ("PSA-1234", TipoPlacaEnum.GUBERNAMENTAL, "Gubernamental Pichincha segunda letra S"),
        # Valores frontera válidos
        ("XXX-0000", TipoPlacaEnum.GUBERNAMENTAL, "Frontera ceros 0000 (segunda letra X gubernamental)"),
        ("XXX-9999", TipoPlacaEnum.GUBERNAMENTAL, "Frontera nueves 9999 (segunda letra X gubernamental)"),
        ("AB-000A", TipoPlacaEnum.MOTO, "Frontera ceros en moto alfanumérica 2L+3D+1L"),
    ],
)
def test_placas_ant_validas_y_clasificacion(placa: str, tipo_esperado: TipoPlacaEnum, descripcion: str):
    """Valida formatos de placas vehiculares permitidos y su clasificación según D5."""
    assert validar_placa_ecuador(placa) is True, f"Falló validación de placa ({descripcion}): {placa}"
    assert clasificar_placa(placa) == tipo_esperado, f"Falló clasificación ({descripcion}): {placa}"


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
        # Valores frontera inválidos
        ("ab-000a", "Moto alfanumérica en minúsculas"),
        ("AB-000a", "Letra final de moto en minúscula"),
        ("AB-12345", "Moto con 5 dígitos"),
    ],
)
def test_placas_ant_invalidas(placa: str, motivo: str):
    """Verifica el rechazo de formatos de placas vehiculares no permitidos y su clasificación None."""
    assert validar_placa_ecuador(placa) is False, f"Se debió rechazar ({motivo}): {placa}"
    assert clasificar_placa(placa) is None, f"Placa inválida debe clasificar como None ({motivo}): {placa}"
