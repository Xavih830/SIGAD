"""Extraction service — two-gate OCR pipeline with 200 DPI sequential memory safety."""

import logging
from decimal import Decimal
import gc
from pathlib import Path
import re

from PIL import Image
import pdfplumber
import pypdfium2 as pdfium
import pytesseract

from app.core.constants import (
    GATE1_TEXT_LENGTH_THRESHOLD,
    MAX_PDF_PAGES_PERMITTED,
    OCR_HIGH_CONFIDENCE_THRESHOLD,
    TESSERACT_STANDARD_DPI,
)

logger = logging.getLogger("sigad.extraccion")


def _extraer_compuerta_1_pdfplumber(file_path: str) -> str:
    """Gate 1: Fast native digital text extraction via pdfplumber."""
    texto_total = []
    try:
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages[:10]:
                txt = page.extract_text()
                if txt:
                    texto_total.append(txt)
    except Exception as exc:
        logger.warning("Fallo en compuerta 1 (pdfplumber) para %s: %s", file_path, exc)
        return ""
    return "\n".join(texto_total).strip()


def _extraer_compuerta_2_tesseract_200dpi(file_path: str) -> str:
    """Gate 2: Sequential rasterization at exactly 200 DPI with explicit memory deallocation."""
    ext = Path(file_path).suffix.lower()
    full_text: list[str] = []

    if ext in [".jpg", ".jpeg", ".png", ".tiff", ".tif"]:
        image_buffer = Image.open(file_path)
        try:
            texto = pytesseract.image_to_string(image_buffer, lang="spa")
            full_text.append(texto)
        except Exception as exc_spa:
            logger.warning(
                "Fallo OCR en español para imagen %s: %s. Reintentando sin idioma.",
                file_path,
                exc_spa,
            )
            try:
                texto = pytesseract.image_to_string(image_buffer)
                full_text.append(texto)
            except Exception as exc_fallback:
                logger.error("Fallo definitivo OCR para imagen %s: %s", file_path, exc_fallback)
        finally:
            del image_buffer
            gc.collect()

    elif ext == ".pdf":
        pdf = pdfium.PdfDocument(file_path)
        total_pages = min(len(pdf), MAX_PDF_PAGES_PERMITTED)
        scale = float(TESSERACT_STANDARD_DPI) / 72.0

        for page_idx in range(total_pages):
            page = pdf[page_idx]
            image_buffer = page.render(scale=scale).to_pil()
            try:
                page_text = pytesseract.image_to_string(image_buffer, lang="spa")
                full_text.append(page_text)
            except Exception as exc_spa:
                logger.warning(
                    "Fallo OCR en español para página %d de %s: %s. Reintentando sin idioma.",
                    page_idx,
                    file_path,
                    exc_spa,
                )
                try:
                    page_text = pytesseract.image_to_string(image_buffer)
                    full_text.append(page_text)
                except Exception as exc_fallback:
                    logger.error(
                        "Fallo definitivo OCR para página %d de %s: %s",
                        page_idx,
                        file_path,
                        exc_fallback,
                    )
                    full_text.append("")
            finally:
                del image_buffer
                del page
                gc.collect()

        pdf.close()

    return "\n".join(full_text).strip()


def extraer_documento_sync(
    file_path: str,
    campos_esquema: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    """Execute the two-gate extraction pipeline on a target file.

    Extracts raw text via Gate 1 (pdfplumber) or Gate 2 (tesseract_200dpi)
    and applies dynamic schema rules via aplicar_esquema().
    
    Returns:
        dict with keys:
            - 'metodo': 'pdfplumber' | 'tesseract_200dpi'
            - 'texto_completo': str
            - 'confianza': float
            - 'campos_extraidos': dict
    """
    ext = Path(file_path).suffix.lower()
    reglas = campos_esquema or []

    if ext == ".pdf":
        texto_digital = _extraer_compuerta_1_pdfplumber(file_path)
        if len(texto_digital.strip()) > GATE1_TEXT_LENGTH_THRESHOLD:
            campos, confianza = aplicar_esquema(texto_digital, reglas)
            return {
                "metodo": "pdfplumber",
                "texto_completo": texto_digital,
                "confianza": confianza,
                "campos_extraidos": campos,
            }

    texto_ocr = _extraer_compuerta_2_tesseract_200dpi(file_path)
    campos, confianza = aplicar_esquema(texto_ocr, reglas)
    return {
        "metodo": "tesseract_200dpi",
        "texto_completo": texto_ocr,
        "confianza": confianza,
        "campos_extraidos": campos,
    }


def evaluar_decision_extraccion(
    legible: bool,
    confianza: float | Decimal,
    coincide_vehiculo: bool = False,
    placa_duplicada: bool = False,
) -> str:
    """Evalúa la regla de decisión canónica de Jorgensen para extracción OCR.

    Tabla canónica reducida:
    R1: Legibilidad = No (False) -> 'Rechazar Documento' (indiferencia en el resto)
    R2: Legible = Sí, Confianza < 80% -> 'Revisión Manual Obligatoria' (indiferencia)
    R3: Legible = Sí, Confianza >= 80%, Placa Duplicada = Sí -> 'Rechazar Documento'
    R4: Legible = Sí, Confianza >= 80%, Coincide = Sí, Duplicada = No -> 'Aprobar Automáticamente'
    R5: Legible = Sí, Confianza >= 80%, Coincide = No, Duplicada = No -> 'Revisión Manual Obligatoria'
    """
    if not legible:
        return "Rechazar Documento"

    conf = Decimal(str(confianza))
    if conf < OCR_HIGH_CONFIDENCE_THRESHOLD:
        return "Revisión Manual Obligatoria"

    if placa_duplicada:
        return "Rechazar Documento"

    if coincide_vehiculo:
        return "Aprobar Automáticamente"

    return "Revisión Manual Obligatoria"


def aplicar_esquema(texto: str, campos: list[dict]) -> tuple[dict, float]:
    """Aplica las reglas JSONB de un EsquemaExtraccion al texto OCR extraído.

    Args:
        texto: Texto plano devuelto por extraer_documento_sync().
        campos: Lista de dicts del campo JSONB del modelo EsquemaExtraccion.

    Returns:
        (resultado: dict[nombre→valor|None], confianza: float 0.0–100.0)

    Raises:
        KeyError: Si un campo no tiene 'nombre' o 'regex' (datos corruptos en BD).
    """
    if not campos:
        return {}, 0.0

    resultado: dict = {}
    aciertos = 0

    for regla in sorted(campos, key=lambda r: int(r.get("orden", 0))):
        nombre = regla["nombre"]
        patron = regla["regex"]
        grupo = int(regla.get("grupo_captura", 1))

        match = re.search(patron, texto, re.IGNORECASE)
        if match:
            total_grupos = len(match.groups())
            if total_grupos == 0:
                valor = match.group(0).strip()
            elif grupo <= total_grupos:
                valor = match.group(grupo).strip()
            else:
                raise IndexError(
                    f"El grupo de captura {grupo} excede los {total_grupos} grupos definidos en el patrón '{patron}' para el campo '{nombre}'."
                )
            resultado[nombre] = valor
            aciertos += 1
        else:
            resultado[nombre] = None

    confianza = round((aciertos / len(campos)) * 100, 2)
    return resultado, confianza
