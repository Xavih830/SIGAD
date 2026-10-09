"""Pruebas unitarias para esquemas de extracción y la función aplicar_esquema."""

import pytest
from pydantic import ValidationError

from app.core.constants import (
    MAX_CAMPOS_POR_ESQUEMA,
    MAX_DESCRIPCION_ESQUEMA_LENGTH,
    MAX_NOMBRE_CAMPO_LENGTH,
    MAX_REGEX_LENGTH,
)
from app.schemas.esquema_extraccion import CampoReglaCreate, EsquemaCreate
from app.services.extraccion_service import aplicar_esquema
from tests.factories.fixtures import (
    CAMPOS_ESQUEMA_HOGAR,
    CAMPOS_ESQUEMA_VEHICULAR,
    CAMPOS_ESQUEMA_VIDA,
    ESQUEMA_CODIGO_HOGAR,
    ESQUEMA_CODIGO_VEHICULAR,
    ESQUEMA_CODIGO_VIDA,
    TEXTO_OCR_HOGAR,
    TEXTO_OCR_VEHICULAR,
    TEXTO_OCR_VIDA,
)
from tests.factories.payloads import (
    campo_regla_payload,
    esquema_hogar_payload,
    esquema_payload,
    esquema_vehicular_payload,
    esquema_vida_payload,
)


def test_aplicar_esquema_dominio_vehicular():
    """Dominio 1: Extracción vehicular extrae 5 campos canónicos con 100% de confianza."""
    campos = [c.copy() for c in CAMPOS_ESQUEMA_VEHICULAR]
    resultado, confianza = aplicar_esquema(TEXTO_OCR_VEHICULAR, campos)

    assert resultado["numero_poliza"] == "POL-2026-004521"
    assert resultado["placa"] == "PBX-1234"
    assert resultado["chasis"] == "1HGCR2F83HA123456"
    assert resultado["valor_asegurado"] == "25,500.00"
    assert resultado["fecha_emision"] == "2026-03-15"
    assert confianza == 100.0


def test_aplicar_esquema_dominio_vida():
    """Dominio 2: Extracción de vida colectiva extrae certificado, titular y beneficiario."""
    campos = [c.copy() for c in CAMPOS_ESQUEMA_VIDA]
    resultado, confianza = aplicar_esquema(TEXTO_OCR_VIDA, campos)

    assert resultado["numero_certificado"] == "849201"
    assert resultado["titular_cedula"] == "0926687856"
    assert resultado["beneficiario_nombre"] == "MARIA JOSE LEON ANDRADE"
    assert resultado["suma_asegurada"] == "50000.00"
    assert resultado["fecha_inicio_vigencia"] == "01/01/2026"
    assert confianza == 100.0


def test_aplicar_esquema_dominio_hogar():
    """Dominio 3: Extracción multirriesgo hogar extrae predio y cobertura de terremoto."""
    campos = [c.copy() for c in CAMPOS_ESQUEMA_HOGAR]
    resultado, confianza = aplicar_esquema(TEXTO_OCR_HOGAR, campos)

    assert resultado["numero_contrato"] == "HOG-99214"
    assert resultado["direccion_predio"] == "URB LA JOYA ETAPA CORAL MZ 12 SL 4"
    assert resultado["cobertura_terremoto"] == "SI"
    assert resultado["prima_neta"] == "450.00"
    assert confianza == 100.0


def test_aplicar_esquema_cruce_dominios_incompatible_retorna_cero():
    """Cruce: aplicar esquema de Hogar a texto OCR de Vehicular resulta en 0% de confianza."""
    campos = [c.copy() for c in CAMPOS_ESQUEMA_HOGAR]
    resultado, confianza = aplicar_esquema(TEXTO_OCR_VEHICULAR, campos)

    assert all(v is None for v in resultado.values())
    assert confianza == 0.0


def test_adversarial_texto_gigante_no_bloquea():
    """Ataque DoS: Texto gigante de 100KB de caracteres aleatorios no debe colgar el algoritmo."""
    texto_gigante = ("LINEA DE RELLENO SIN COINCIDENCIAS ABC-9999\n" * 2500)
    campos = [c.copy() for c in CAMPOS_ESQUEMA_VEHICULAR]

    resultado, confianza = aplicar_esquema(texto_gigante, campos)
    assert isinstance(confianza, float)
    assert isinstance(resultado, dict)


def test_adversarial_caracteres_especiales_y_emojis():
    """Texto con emojis, saltos de línea mezclados y símbolos monetarios exóticos."""
    texto = "🚗 POLIZA VEHICULAR 🛡️\nPLACA: ABC-1234 💥\nVALOR: $ 10,000.00 €\nCHASIS: 1HGCR2F83HA123456"
    campos = [c.copy() for c in CAMPOS_ESQUEMA_VEHICULAR]

    resultado, confianza = aplicar_esquema(texto, campos)
    assert resultado["placa"] == "ABC-1234"
    assert resultado["chasis"] == "1HGCR2F83HA123456"


def test_adversarial_orden_de_reglas_respetado():
    """Garantiza que las reglas se procesen según el atributo 'orden' aunque vengan desordenadas."""
    campos_desordenados = [
        campo_regla_payload(nombre="campo_3", orden=3, regex=r"TRES"),
        campo_regla_payload(nombre="campo_1", orden=1, regex=r"UNO"),
        campo_regla_payload(nombre="campo_2", orden=2, regex=r"DOS"),
    ]
    resultado, _ = aplicar_esquema("UNO DOS TRES", campos_desordenados)
    assert list(resultado.keys()) == ["campo_1", "campo_2", "campo_3"]


def test_adversarial_datos_corruptos_lanza_keyerror_fail_fast():
    """Principio Fail-Fast Radical: ausencia de 'nombre' o 'regex' en BD rompe inmediatamente."""
    corrupted_1 = campo_regla_payload()
    corrupted_1.pop("nombre")
    with pytest.raises(KeyError):
        aplicar_esquema("texto", [corrupted_1])

    corrupted_2 = campo_regla_payload()
    corrupted_2.pop("regex")
    with pytest.raises(KeyError):
        aplicar_esquema("texto", [corrupted_2])


def test_adversarial_lista_vacia():
    """Lista vacía de campos retorna diccionario vacío y confianza 0.0."""
    resultado, confianza = aplicar_esquema("cualquier texto", [])
    assert resultado == {}
    assert confianza == 0.0


@pytest.mark.parametrize("evil_regex", [
    r"(a+)+",
    r"([0-9]+)+",
    r"((a*)*)*",
    r"([a-zA-Z]+)*",
    r"(((((((((((a)))))))))))",
    r"[A-Z+(",
])
def test_adversarial_rechazo_evil_regex_anti_redos(evil_regex: str):
    """Anti-ReDoS: Pydantic DEBE rechazar cualquier regex catastrófico antes de persistirlo."""
    payload = campo_regla_payload(regex=evil_regex)
    with pytest.raises(ValidationError):
        CampoReglaCreate(**payload)


@pytest.mark.parametrize("payload_nulo", [
    campo_regla_payload(nombre="campo\x00nulo"),
    campo_regla_payload(regex="placa\x00test"),
])
def test_adversarial_null_byte_injection_rechazado(payload_nulo: dict):
    """Anti-Exploit: rechaza inyecciones de bytes nulos en campos de regla."""
    with pytest.raises(ValidationError):
        CampoReglaCreate(**payload_nulo)


def test_adversarial_campos_duplicados_en_mismo_esquema_rechazado():
    """Integridad: prohíbe que un esquema defina dos campos con el mismo nombre."""
    campo_1 = campo_regla_payload(nombre="placa", orden=0)
    campo_2 = campo_regla_payload(nombre="placa", orden=1)
    payload = esquema_payload(campos=[campo_1, campo_2])

    with pytest.raises(ValidationError) as exc_info:
        EsquemaCreate(**payload)
    assert "campos duplicados" in str(exc_info.value)


def test_adversarial_incoherencia_fecha_y_formato():
    """Incoherencia de tipos: 'fecha' requiere 'formato_fecha'; otros tipos lo prohíben."""
    with pytest.raises(ValidationError) as exc_1:
        CampoReglaCreate(**campo_regla_payload(tipo="fecha", formato_fecha=None))
    assert "formato_fecha es obligatorio" in str(exc_1.value)

    with pytest.raises(ValidationError) as exc_2:
        CampoReglaCreate(**campo_regla_payload(tipo="texto", formato_fecha="YYYY-MM-DD"))
    assert "solo es aplicable cuando tipo='fecha'" in str(exc_2.value)


@pytest.mark.parametrize("codigo_invalido", [
    "codigo con espacios",
    "codigo_en_minusculas",
    "CODIGO-CON-GUION-MEDIO",
    "CODIGO$ESPECIAL#",
    "<script>alert(1)</script>",
    "CODIGO\x00NULO",
    "",
    "A" * 81,
])
def test_adversarial_codigo_esquema_formatos_invalidos(codigo_invalido: str):
    """El código del esquema debe cumplir estrictamente el patrón ^[A-Z0-9_]+$."""
    payload = esquema_payload(codigo=codigo_invalido)
    with pytest.raises(ValidationError):
        EsquemaCreate(**payload)


def test_adversarial_limites_cardinalidad_campos():
    """Límites de campos: mínimo 1 y máximo MAX_CAMPOS_POR_ESQUEMA (50)."""
    with pytest.raises(ValidationError):
        EsquemaCreate(**esquema_payload(campos=[]))

    muchos_campos = [campo_regla_payload(nombre=f"c_{i}") for i in range(MAX_CAMPOS_POR_ESQUEMA + 1)]
    with pytest.raises(ValidationError):
        EsquemaCreate(**esquema_payload(campos=muchos_campos))


def test_adversarial_inyeccion_atributos_extra_bloqueada():
    """StrictBaseSchema: rechaza campos no autorizados (previene over-posting y mass-assignment)."""
    payload_esquema = esquema_payload(inyeccion_no_declarada=True)
    with pytest.raises(ValidationError):
        EsquemaCreate(**payload_esquema)

    payload_campo = campo_regla_payload(parametro_malicioso="ataque")
    with pytest.raises(ValidationError):
        CampoReglaCreate(**payload_campo)


def test_preset_vehicular_valido():
    """Verifica que el builder canónico de póliza vehicular cumpla el esquema."""
    payload = esquema_vehicular_payload()
    esquema = EsquemaCreate(**payload)
    assert esquema.codigo == ESQUEMA_CODIGO_VEHICULAR
    assert len(esquema.campos) == len(CAMPOS_ESQUEMA_VEHICULAR)


def test_preset_vida_valido():
    """Verifica que el builder canónico de póliza de vida colectiva cumpla el esquema."""
    payload = esquema_vida_payload()
    esquema = EsquemaCreate(**payload)
    assert esquema.codigo == ESQUEMA_CODIGO_VIDA
    assert len(esquema.campos) == len(CAMPOS_ESQUEMA_VIDA)


def test_preset_hogar_valido():
    """Verifica que el builder canónico de póliza de hogar cumpla el esquema."""
    payload = esquema_hogar_payload()
    esquema = EsquemaCreate(**payload)
    assert esquema.codigo == ESQUEMA_CODIGO_HOGAR
    assert len(esquema.campos) == len(CAMPOS_ESQUEMA_HOGAR)
