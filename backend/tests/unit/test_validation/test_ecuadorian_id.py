"""Unit tests for Ecuadorian ID (Módulo 10) validation algorithm."""

from app.schemas.cliente import (
    validar_cedula_ecuatoriana,
    validar_identificacion,
    validar_ruc_ecuatoriano,
)


def test_valid_ecuadorian_ids():
    """Valid IDs should be accepted."""
    assert validar_cedula_ecuatoriana("0926687856") is True  # Guayas
    assert validar_cedula_ecuatoriana("1710034065") is True  # Pichincha
    assert validar_cedula_ecuatoriana(" 0926687856 ") is True  # Leading/trailing whitespace trimmed
    assert validar_cedula_ecuatoriana("3000000020") is True  # Registro especial en el exterior (provincia 30)



def test_invalid_length_ids():
    """IDs with length != 10 must be rejected."""
    assert validar_cedula_ecuatoriana("092668785") is False  # 9 digits
    assert validar_cedula_ecuatoriana("09266878561") is False  # 11 digits
    assert validar_cedula_ecuatoriana("") is False  # Empty


def test_non_numeric_ids():
    """Non-numeric IDs must be rejected."""
    assert validar_cedula_ecuatoriana("092668785a") is False
    assert validar_cedula_ecuatoriana("abcdefghij") is False
    assert validar_cedula_ecuatoriana("0926 68785") is False


def test_invalid_province_code():
    """Provinces outside [1, 24] and not 30 must be rejected."""
    assert validar_cedula_ecuatoriana("0026687856") is False  # Province 00
    assert validar_cedula_ecuatoriana("2526687856") is False  # Province 25
    assert validar_cedula_ecuatoriana("9926687856") is False  # Province 99


def test_invalid_third_digit():
    """Third digit > 5 (not natural person) must be rejected."""
    assert validar_cedula_ecuatoriana("0966687856") is False  # Third digit 6
    assert validar_cedula_ecuatoriana("1790034065") is False  # Third digit 9


def test_invalid_verifier_digit():
    """Check digit mismatch must be rejected."""
    assert validar_cedula_ecuatoriana("0926687857") is False  # Expected 6, got 7
    assert validar_cedula_ecuatoriana("1710034064") is False  # Expected 5, got 4


def test_valid_ruc_types():
    """Valid RUCs for natural, public, and private entities must be accepted."""
    # Persona natural: cédula válida + establecimiento 001
    assert validar_ruc_ecuatoriano("0926687856001") is True
    assert validar_ruc_ecuatoriano("1710034065001") is True
    # Sociedad pública (3er dígito 6): Módulo 11 con 8 dígitos
    assert validar_ruc_ecuatoriano("1760000820001") is True
    # Sociedad privada / extranjera (3er dígito 9): Módulo 11 con 9 dígitos
    assert validar_ruc_ecuatoriano("1790016919001") is True


def test_invalid_rucs():
    """Invalid RUCs must be rejected."""
    assert validar_ruc_ecuatoriano("092668785600") is False  # 12 digits
    assert validar_ruc_ecuatoriano("09266878560001") is False  # 14 digits
    assert validar_ruc_ecuatoriano("092668785600a") is False  # non-numeric
    assert validar_ruc_ecuatoriano("0026687856001") is False  # invalid province
    assert validar_ruc_ecuatoriano("0926687856000") is False  # invalid establishment 000
    assert validar_ruc_ecuatoriano("1760000830001") is False  # wrong check digit public
    assert validar_ruc_ecuatoriano("1790016918001") is False  # wrong check digit private
    assert validar_ruc_ecuatoriano("1770016919001") is False  # invalid 3rd digit (7)
    assert validar_ruc_ecuatoriano("1780016919001") is False  # invalid 3rd digit (8)


def test_validar_identificacion():
    """validar_identificacion should accept either 10-digit cédula or 13-digit RUC."""
    assert validar_identificacion("0926687856") is True
    assert validar_identificacion("1790016919001") is True
    assert validar_identificacion("1760000820001") is True
    assert validar_identificacion("0926687856001") is True
    assert validar_identificacion("12345") is False
    assert validar_identificacion("0926687857") is False
    assert validar_identificacion("1790016918001") is False
