# SIGAD – Sistema de Gestión y Análisis Documental de Pólizas Vehiculares

SIGAD es una solución integral desarrollada para **RJ Seguros** para la gestión, tarificación, vinculación y análisis documental automatizado de pólizas de seguros vehiculares mediante extracción digital y OCR.

---

## 1. Guía de Commits Atómicos y Buenas Prácticas Git

Para preservar la trazabilidad, evitar regresiones silenciosas y permitir revisiones de código eficientes (PRs pequeños y legibles), **se prohíben estrictamente los mega-commits que mezclen múltiples subsistemas o capas**. 

### 1.1 Principio de Atomicidad por Commit
* **Una única responsabilidad por commit:** Cada commit debe resolver una única tarea técnica bien delimitada (un bug, una migración, un endpoint con sus pruebas, o un widget modular).
* **Compilación y pruebas en verde:** Cada commit individual en el historial debe compilar y mantener las pruebas unitarias e integración en verde.
* **Granularidad dentro de un mismo plan:** Un plan técnico **NO** debe completarse en un único commit gigante. Debe subdividirse en commits atómicos siguiendo el flujo natural del Grafo de Tareas (DAG). Por ejemplo:
  1. *Commit 1 (Contrato/Modelo):* `feat(backend): agregar modelo y esquema pydantic de ...`
  2. *Commit 2 (Migración BD):* `feat(db): crear migracion alembic para tabla ...`
  3. *Commit 3 (Lógica/Endpoint + Tests):* `feat(api): implementar endpoint ... y pruebas automatizadas`
  4. *Commit 4 (UI/Presentación):* `feat(ui): conectar vista modular de ... al endpoint`

### 1.2 Formato de Conventional Commits (en Español)
Todos los commits deben seguir la estructura:
```text
<tipo>(<alcance>): <descripción corta en imperativo>
```

#### Tipos Permitidos:
* **`feat`:** Nueva funcionalidad o nuevo endpoint/componente.
* **`fix`:** Corrección de un defecto o fallo en tiempo de ejecución.
* **`refactor`:** Cambio en la estructura del código sin alterar su comportamiento externo ni agregar endpoints.
* **`test`:** Adición o actualización de pruebas unitarias, de integración o de carga.
* **`chore`:** Tareas de mantenimiento, dependencias o configuración del entorno.
* **`docs`:** Documentación técnica o cambios en especificaciones.

#### Ejemplos Correctos:
* `feat(polizas): implementar evaluador de dominio cfg y calculo de vigencia`
* `test(polizas): agregar pruebas unitarias para caminos independientes del cfg`
* `feat(db): agregar trigger postgresql para auditoria en historial_cambios`
* `refactor(frontend): desacoplar dialogo de vinculacion otp a widget independiente`
* `fix(auth): corregir manejo de tiempos constantes ante usuarios no registrados`

---

## 2. Pila Tecnológica

* **Frontend:** Flutter Web y Android (Clean Architecture, BLoC, modelos inmutables).
* **Backend:** FastAPI (Python 3.11+), SQLAlchemy 2.0 Async, Pydantic v2.
* **Base de Datos:** PostgreSQL 16 con migraciones Alembic y triggers en PL/pgSQL.
* **Workers & OCR:** Subproceso aislado `ProcessPoolExecutor`, pdfplumber y Tesseract 5 a 200 DPI.
* **Proxy Inverso:** Caddy 2.

---

## 3. Configuración del Entorno de Desarrollo

### 3.1 Variables de Entorno

El proyecto separa estrictamente la configuración del servidor de la del cliente:

1. **Backend y Servicios (Raíz del proyecto):**
   Copiar la plantilla de configuración canónica:
   ```bash
   cp .env.example .env
   ```
   Configurar los valores requeridos (`POSTGRES_*`, `DATABASE_URL`, `JWT_SECRET_KEY`, `OTP_SECRET_KEY_*`, `UPLOAD_DIR`, etc.).

2. **Frontend Flutter:**
   Copiar la plantilla para el cliente:
   ```bash
   cp .env.client.example .env.client
   ```
   Ajustar `API_BASE_URL` (por defecto `http://localhost:8000` o la URL del gateway).

---

## 4. Ejecución del Proyecto

### Opción A: Contenedores (Docker Compose)
Levanta la infraestructura completa (PostgreSQL, FastAPI API, OCR Worker, Mailpit y Caddy):
```bash
docker compose up --build
```
* **API REST:** `http://localhost:8000` (o `http://localhost:8085/api/v1` vía Caddy)
* **Documentación interactiva (Swagger):** `http://localhost:8000/docs`
* **Mailpit (Buzón de correos de prueba):** `http://127.0.0.1:8025`

### Opción B: Ejecución Local

**Backend:**
```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # En Windows: .venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
python -m scripts.seed_dev_data  # Datos de prueba para desarrollo
uvicorn app.main:app --reload --port 8000
```

**Frontend (Flutter):**
```bash
# Inyectando variables desde .env.client
flutter run -d chrome --dart-define-from-file=.env.client

# O pasando directamente la URL base
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

---

## 5. Ejecución de Pruebas y Compuertas de Calidad

Antes de realizar commits o pull requests, deben ejecutarse y pasar las siguientes suites:

### 5.1 Pruebas del Backend (Pytest)
Desde la raíz del proyecto o dentro del directorio `backend/`:
```bash
cd backend
PYTHONPATH=. .venv/bin/pytest tests/
```
* Para ejecutar únicamente pruebas unitarias o de calidad de arquitectura:
  ```bash
  PYTHONPATH=. .venv/bin/pytest tests/unit/test_quality/test_architecture_config.py
  ```

### 5.2 Análisis y Pruebas del Frontend (Flutter)
Desde la raíz del proyecto:
```bash
# Análisis estático de código
flutter analyze

# Suite de pruebas unitarias y de widgets
flutter test
```
