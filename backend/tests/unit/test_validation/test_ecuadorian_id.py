"""Unit tests for Ecuadorian ID (Módulo 10) validation algorithm."""

import pytest
from app.schemas.cliente import validar_cedula_ecuatoriana


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
