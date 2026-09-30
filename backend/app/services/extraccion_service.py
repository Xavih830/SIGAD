"""Extraction service — two-gate OCR pipeline with 200 DPI sequential memory safety."""

from decimal import Decimal
import gc
import os
from pathlib import Path
import re
from typing import Any

from PIL import Image
import pdfplumber
import pypdfium2 as pdfium
import pytesseract

COMMON_BRANDS = [
    "TOYOTA", "CHEVROLET", "HYUNDAI", "KIA", "NISSAN",
    "FORD", "MAZDA", "HINO", "SUZUKI", "RENAULT",
    "VOLKSWAGEN", "MITSUBISHI", "CHERY", "GREAT WALL", "ISUZU",
]

COMMON_MODELS = [
    "COROLLA", "YARIS", "HILUX", "RAV4", "ONIX", "AVEO", "D-MAX", "SAIL",
    "TUCSON", "ACCENT", "SANTA FE", "SPORTAGE", "RIO", "CERATO", "PICANTO",
    "300", "500", "RANGER", "F-150", "DIMAX", "SZ", "GRAND VITARA",
]


def extraer_campos_regex(texto: str) -> tuple[dict[str, Any], Decimal]:
    """Parse key vehicle registration and policy fields using regex rules."""
    texto_upper = texto.upper()
    campos: dict[str, Any] = {
        "placa": None,
        "chasis": None,
        "motor": None,
        "marca": None,
        "modelo": None,
        "anio": None,
    }

    # 1. Placa: Formato ecuatoriano AAA-0123 o AAA-123 o AAA0123
    placa_match = re.search(r"\b([A-Z]{3})[- ]?(\d{3,4})\b", texto_upper)
    if placa_match:
        campos["placa"] = f"{placa_match.group(1)}-{placa_match.group(2)}"

    # 2. Chasis / VIN: 17 caracteres alfanuméricos estándar ISO 3779
    vin_keyword_match = re.search(r"(?:CHASIS|VIN|SERIE)[\s:]+([A-HJ-NPR-Z0-9]{11,17})", texto_upper)
    if vin_keyword_match:
        campos["chasis"] = vin_keyword_match.group(1).strip()
    else:
        vin_match = re.search(r"\b([A-HJ-NPR-Z0-9]{17})\b", texto_upper)
        if vin_match:
            campos["chasis"] = vin_match.group(1)

    # 3. Motor
    motor_match = re.search(r"(?:MOTOR|ENGINE)[\s:]+([A-Z0-9\-]{5,20})", texto_upper)
    if motor_match:
        campos["motor"] = motor_match.group(1).strip()

    # 4. Marca
    for brand in COMMON_BRANDS:
        if re.search(rf"\b{re.escape(brand)}\b", texto_upper):
            campos["marca"] = brand.capitalize()
            break

    # 5. Modelo
    for model in COMMON_MODELS:
        if re.search(rf"\b{re.escape(model)}\b", texto_upper):
            campos["modelo"] = model.capitalize()
            break

    # 6. Año
    anio_match = re.search(r"(?:A[ÑN]O|FABRICACI[OÓ]N|MODELO)?[\s:]*\b(19\d{2}|20[0-2]\d)\b", texto_upper)
    if anio_match:
        campos["anio"] = int(anio_match.group(1))

    # Cálculo ponderado de confianza
    confianza = Decimal("10.00")
    if campos["placa"]:
        confianza += Decimal("25.00")
    if campos["chasis"]:
        confianza += Decimal("25.00")
    if campos["motor"]:
        confianza += Decimal("15.00")
    if campos["marca"]:
        confianza += Decimal("15.00")
    if campos["modelo"]:
        confianza += Decimal("5.00")
    if campos["anio"]:
        confianza += Decimal("5.00")

    if confianza > Decimal("100.00"):
        confianza = Decimal("100.00")

    return campos, confianza


def _extraer_compuerta_1_pdfplumber(file_path: str) -> str:
    """Gate 1: Fast native digital text extraction via pdfplumber."""
    texto_total = []
    try:
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages[:10]:
                txt = page.extract_text()
                if txt:
                    texto_total.append(txt)
    except Exception:
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
        except Exception:
            try:
                texto = pytesseract.image_to_string(image_buffer)
                full_text.append(texto)
            except Exception:
                pass
        finally:
            del image_buffer
            gc.collect()

    elif ext == ".pdf":
        pdf = pdfium.PdfDocument(file_path)
        total_pages = min(len(pdf), 10)
        scale = 200.0 / 72.0  # Exact 200 DPI scale factor (PDF base is 72 pt)

        for page_idx in range(total_pages):
            page = pdf[page_idx]
            image_buffer = page.render(scale=scale).to_pil()
            try:
                page_text = pytesseract.image_to_string(image_buffer, lang="spa")
                full_text.append(page_text)
            except Exception:
                try:
                    page_text = pytesseract.image_to_string(image_buffer)
                    full_text.append(page_text)
                except Exception:
                    full_text.append("")
            finally:
                # Liberación explícita e inmediata de búferes de imagen y llamada a recolector
                del image_buffer
                del page
                gc.collect()

        pdf.close()

    return "\n".join(full_text).strip()


def extraer_documento_sync(file_path: str) -> dict[str, Any]:
    """Execute the two-gate extraction pipeline on a target file.
    
    Returns:
        dict with keys:
            - 'metodo': 'pdfplumber' | 'tesseract_200dpi'
            - 'texto_completo': str
            - 'confianza': Decimal
            - 'campos_extraidos': dict
    """
    ext = Path(file_path).suffix.lower()

    # Compuerta 1: Solo aplica para PDFs
    if ext == ".pdf":
        texto_digital = _extraer_compuerta_1_pdfplumber(file_path)
        if len(texto_digital.strip()) > 50:
            campos, confianza = extraer_campos_regex(texto_digital)
            return {
                "metodo": "pdfplumber",
                "texto_completo": texto_digital,
                "confianza": confianza,
                "campos_extraidos": campos,
            }

    # Compuerta 2: Documentos escaneados, imágenes o PDFs sin texto embebido
    texto_ocr = _extraer_compuerta_2_tesseract_200dpi(file_path)
    campos, confianza = extraer_campos_regex(texto_ocr)
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
    if conf < Decimal("80.0"):
        return "Revisión Manual Obligatoria"

    if placa_duplicada:
        return "Rechazar Documento"

    if coincide_vehiculo:
        return "Aprobar Automáticamente"

    return "Revisión Manual Obligatoria"
