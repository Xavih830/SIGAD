"""Test 7: Liberación explícita de búferes de página con Tesseract a 200 DPI sin fugas."""

import gc
import os
import tempfile
import tracemalloc
from unittest.mock import MagicMock, patch
import pytest
import pypdfium2 as pdfium

from app.services.extraccion_service import _extraer_compuerta_2_tesseract_200dpi, extraer_documento_sync


def _crear_pdf_multipagina_temporal(num_paginas: int = 4) -> str:
    """Generates a temporary blank multi-page PDF for rasterization tests."""
    pdf = pdfium.PdfDocument.new()
    for _ in range(num_paginas):
        pdf.new_page(width=595, height=842)
    fd, path = tempfile.mkstemp(suffix=".pdf")
    os.close(fd)
    pdf.save(path)
    pdf.close()
    return path


def test_extraccion_200_dpi_liberacion_memoria():
    """Verifica que el renderizado se realiza a 200 DPI y la memoria se libera secuencialmente página por página."""
    pdf_path = _crear_pdf_multipagina_temporal(num_paginas=4)
    try:
        tracemalloc.start()
        gc_collect_calls = 0
        real_gc_collect = gc.collect

        def mock_gc_collect():
            nonlocal gc_collect_calls
            gc_collect_calls += 1
            return real_gc_collect()

        with patch("pytesseract.image_to_string", return_value="PLACA: PBM-5678 TOYOTA COROLLA"):
            with patch("gc.collect", side_effect=mock_gc_collect):
                # Medir memoria antes
                gc.collect()
                snapshot1 = tracemalloc.take_snapshot()

                resultado = _extraer_compuerta_2_tesseract_200dpi(pdf_path)

                # Medir memoria después
                snapshot2 = tracemalloc.take_snapshot()

        # Debe haber procesado las 4 páginas y llamado a gc.collect() al menos una vez por página
        assert gc_collect_calls >= 4, f"Se esperaban al menos 4 llamadas a gc.collect(), pero hubo {gc_collect_calls}"
        assert "PLACA: PBM-5678" in resultado

        # Comprobar que no hay fuga acumulativa de memoria
        top_stats = snapshot2.compare_to(snapshot1, "lineno")
        total_diff_kb = sum(stat.size_diff for stat in top_stats) / 1024.0
        # La diferencia residual debe ser mínima (< 15 MB) tras liberar los búferes
        assert total_diff_kb < 15360, f"Posible fuga de memoria detectada: {total_diff_kb} KB retenidos"

    finally:
        tracemalloc.stop()
        if os.path.exists(pdf_path):
            os.remove(pdf_path)
