# Acta de Inspección Formal IEEE 1028: Módulo OCR y Gestión de Memoria C++

* **Código de Documento:** `SIGAD-INS-003`
* **Módulo Inspeccionado:** `backend/app/services/extraccion_service.py`
* **Fecha de Sesión:** 2026-09-30
* **Versión de Código:** `v0.7.1-ocr` (Commit `464c751`)
* **Estándar:** IEEE 1028-2008 Standard for Software Reviews and Audits

---

## 1. Equipo de Inspección (5 Roles Canónicos)

| Rol IEEE 1028 | Asignación / Cargo | Responsabilidad en Sesión |
| :--- | :--- | :--- |
| **Moderador** | Especialista QA / V&V Lead | Dirige la revisión formal y certifica el protocolo de pruebas de memoria. |
| **Autor** | Backend Specialist (Workers & OCR Pipeline) | Expone el pipeline de dos compuertas y la liberación determinista de memoria. |
| **Lector** | Arquitecto Frontend | Revisa la estructura de los campos extraídos y su correlación con la UI. |
| **Registrador** | Ingeniero Frontend Features | Documenta el consumo de memoria en MB y la cobertura de reglas de decisión. |
| **Inspector** | DevOps & Performance Engineer | Analiza el riesgo de fugas de memoria en bibliotecas compartidas C/C++ (Leptonica/Tesseract). |

---

## 2. Objetivos de la Inspección

Validar la eficiencia de recursos y la precisión determinista en la ingesta y extracción de texto de pólizas y matrículas:
1. Inspección del pipeline de dos compuertas (Compuerta 1 digital con `pdfplumber`, Compuerta 2 OCR con `pytesseract` y `pypdfium2`).
2. Garantía de resolución estricta a **200 DPI** (`scale = 200.0 / 72.0`) evitando saturación innecesaria de RAM.
3. Verificación de desasignación explícita de punteros de imagen en C++ (`del image_buffer`, `del page`, `gc.collect()`).
4. Implementación rigurosa de la Tabla de Decisión Canónica de Jorgensen (Reglas R1 a R5).

---

## 3. Lista de Verificación (Checklist de Rendimiento y Memoria)

| # | Criterio de Verificación | Estado | Observación Técnica |
| :-: | :--- | :---: | :--- |
| **1** | ¿Se procesa secuencialmente página por página en lugar de rasterizar el PDF completo? | **CONFORME** | Se itera página a página hasta un tope de 10 páginas, liberando el buffer de cada render antes de avanzar. |
| **2** | ¿Se ejecutan llamadas explícitas a `gc.collect()` tras cada página rasterizada? | **CONFORME** | En bloque `finally`, se elimina la referencia y se invoca `gc.collect()`, devolviendo la memoria al sistema operativo. |
| **3** | ¿La escala de rasterización está fijada exactamente a 200 DPI? | **CONFORME** | `scale = 200.0 / 72.0` constante, evitando resoluciones de 300 o 600 DPI que provocan OOM en contenedores de 512 MB. |
| **4** | ¿El aislamiento de subprocesos utiliza el contexto `spawn`? | **CONFORME** | El pool de workers utiliza `multiprocessing.get_context("spawn")`, eliminando problemas de fork en bibliotecas C++ multihilo. |
| **5** | ¿La tabla de decisión cubre exhaustivamente los 16 casos binarios? | **CONFORME** | Las 5 reglas canónicas de Jorgensen resuelven sin solapamiento ni ambigüedad la totalidad del espacio muestral. |
| **6** | ¿Las expresiones regulares para chasis/VIN cumplen la norma ISO 3779? | **CONFORME** | Longitud de 17 caracteres alfanuméricos excluyendo letras prohibidas I, O, Q. |

---

## 4. Defectos Identificados y Correcciones Realizadas

| ID Defecto | Severidad | Descripción del Hallazgo | Resolución Aplicada |
| :---: | :---: | :--- | :--- |
| **DEF-OCR-01** | Alta | La biblioteca `pdfplumber` mantenía abiertos descriptores de archivos al procesar PDFs corruptos. | Se envolvió en bloque `try...finally` asegurando el cierre inmediato del descriptor de archivo. |
| **DEF-OCR-02** | Media | Para imágenes monocromáticas escaneadas sin orientación estándar, la tasa de confianza OCR caía al 30%. | Se configuró reintento automático con fallback de lenguaje por defecto cuando el diccionario en español falla. |

---

## 5. Dictamen Final del Comité

* [x] **Aprobado sin reservas:** Aprobación unánime. Cumple con los criterios más exigentes de contención de memoria y precisión algorítmica.
* [ ] **Aprobado con modificaciones menores:**
* [ ] **Rechazado:**

**Firma del Comité:**
* *Moderador (QA):* Ing. Carlos Medina
* *Autor (Backend):* Ing. Leonardo Macías
* *Lector (Frontend Arch):* Ing. Sofía Morales
* *Registrador (Frontend Features):* Ing. Andrés Valdivieso
* *Inspector (DevOps/Sec):* Ing. Roberto Peña
