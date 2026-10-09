"""Pruebas de tabla de decisión para el servicio de extracción OCR."""

from decimal import Decimal
import itertools
import pytest

from app.services.extraccion_service import evaluar_decision_extraccion


def test_regla_1_no_legible_rechaza_indiferente_a_otras_condiciones():
    """R1: If document is not legible, it MUST be rejected regardless of other variables."""
    for conf in [Decimal("10.0"), Decimal("79.9"), Decimal("80.0"), Decimal("95.0")]:
        for coincide in [True, False]:
            for duplicada in [True, False]:
                res = evaluar_decision_extraccion(
                    legible=False,
                    confianza=conf,
                    coincide_vehiculo=coincide,
                    placa_duplicada=duplicada,
                )
                assert res == "Rechazar Documento", (
                    f"R1 violation: Expected 'Rechazar Documento' when legible=False, got '{res}'"
                )


def test_regla_2_baja_confianza_requiere_revision_manual():
    """R2: If document is legible but confidence < 80%, manual review is mandatory."""
    for conf in [Decimal("0.0"), Decimal("45.5"), Decimal("79.99")]:
        for coincide in [True, False]:
            for duplicada in [True, False]:
                res = evaluar_decision_extraccion(
                    legible=True,
                    confianza=conf,
                    coincide_vehiculo=coincide,
                    placa_duplicada=duplicada,
                )
                assert res == "Revisión Manual Obligatoria", (
                    f"R2 violation: Expected 'Revisión Manual Obligatoria' for conf={conf}, got '{res}'"
                )


def test_regla_3_placa_duplicada_rechaza_aun_con_alta_confianza():
    """R3: If confidence >= 80% but license plate is duplicated in DB, document must be rejected."""
    for conf in [Decimal("80.0"), Decimal("90.0"), Decimal("100.0")]:
        for coincide in [True, False]:
            res = evaluar_decision_extraccion(
                legible=True,
                confianza=conf,
                coincide_vehiculo=coincide,
                placa_duplicada=True,
            )
            assert res == "Rechazar Documento", (
                f"R3 violation: Expected 'Rechazar Documento' when plate is duplicate, got '{res}'"
            )


def test_regla_4_aprobacion_automatica():
    """R4: High confidence (>=80%), matches vehicle in DB, and not duplicate -> Auto-approve."""
    for conf in [Decimal("80.0"), Decimal("85.0"), Decimal("100.0")]:
        res = evaluar_decision_extraccion(
            legible=True,
            confianza=conf,
            coincide_vehiculo=True,
            placa_duplicada=False,
        )
        assert res == "Aprobar Automáticamente"


def test_regla_5_discrepancia_vehiculo_revision_manual():
    """R5: High confidence (>=80%), not duplicate, but discrepancies with DB -> Manual review."""
    for conf in [Decimal("80.0"), Decimal("95.0"), Decimal("100.0")]:
        res = evaluar_decision_extraccion(
            legible=True,
            confianza=conf,
            coincide_vehiculo=False,
            placa_duplicada=False,
        )
        assert res == "Revisión Manual Obligatoria"


def test_fronteras_confianza_80_por_ciento():
    """Boundary value analysis on the critical 80.0% confidence threshold."""
    res_below = evaluar_decision_extraccion(
        legible=True,
        confianza=79.99,
        coincide_vehiculo=True,
        placa_duplicada=False,
    )
    assert res_below == "Revisión Manual Obligatoria"

    res_exact = evaluar_decision_extraccion(
        legible=True,
        confianza=80.00,
        coincide_vehiculo=True,
        placa_duplicada=False,
    )
    assert res_exact == "Aprobar Automáticamente"

    res_above = evaluar_decision_extraccion(
        legible=True,
        confianza=80.01,
        coincide_vehiculo=True,
        placa_duplicada=False,
    )
    assert res_above == "Aprobar Automáticamente"


def test_completitud_y_consistencia_16_combinaciones():
    """Jorgensen Completeness & Consistency check: All 2^4 = 16 combinations are deterministically resolved."""
    actions_found = set()
    binary_states = [True, False]

    for legible, alta_conf, coincide, duplicada in itertools.product(binary_states, repeat=4):
        conf = Decimal("85.0") if alta_conf else Decimal("50.0")
        decision = evaluar_decision_extraccion(
            legible=legible,
            confianza=conf,
            coincide_vehiculo=coincide,
            placa_duplicada=duplicada,
        )
        assert decision in [
            "Rechazar Documento",
            "Revisión Manual Obligatoria",
            "Aprobar Automáticamente",
        ], f"Unexpected decision '{decision}'"
        actions_found.add(decision)

    assert len(actions_found) == 3
