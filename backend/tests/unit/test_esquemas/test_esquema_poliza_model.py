"""Pruebas unitarias para el modelo ORM EsquemaPoliza y relación con Poliza."""

import uuid

from app.models import EsquemaPoliza, Poliza


def test_esquema_poliza_instanciacion():
    """El modelo EsquemaPoliza debe instanciarse con campos declarativos válidos."""
    campos = [
        {"nombre": "tipo_carga", "tipo": "texto", "es_obligatorio": True, "orden": 1},
        {"nombre": "dispositivo_gps", "tipo": "booleano", "es_obligatorio": True, "orden": 2},
    ]
    esquema = EsquemaPoliza(
        codigo="VEHICULAR_PESADOS",
        nombre="Póliza Carga Pesada",
        descripcion="Seguro para transporte pesado",
        version=1,
        es_activo=True,
        campos=campos,
    )

    assert esquema.codigo == "VEHICULAR_PESADOS"
    assert esquema.nombre == "Póliza Carga Pesada"
    assert esquema.version == 1
    assert esquema.es_activo is True
    assert len(esquema.campos) == 2
    assert esquema.campos[0]["nombre"] == "tipo_carga"


def test_poliza_modelo_acepta_esquema_id_y_campos_adicionales():
    """El modelo Poliza debe soportar esquema_id foráneo y campos_adicionales JSONB."""
    esquema_id = uuid.uuid4()
    campos_adicionales = {
        "tipo_carga": "refrigerada",
        "dispositivo_gps": True,
        "placa_remolque": "REM-9921",
    }
    poliza = Poliza(
        numero_poliza="POL-2026-TEST-001",
        esquema_id=esquema_id,
        campos_adicionales=campos_adicionales,
    )

    assert poliza.esquema_id == esquema_id
    assert poliza.campos_adicionales["tipo_carga"] == "refrigerada"
    assert poliza.campos_adicionales["dispositivo_gps"] is True
