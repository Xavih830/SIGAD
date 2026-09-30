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

* **Frontend:** Flutter Web y Android (Clean Architecture pragmática, State Management BLoC, modelos inmutables).
* **Backend:** FastAPI (Python 3.11), SQLAlchemy 2.0 Async, Pydantic v2.
* **Base de Datos:** PostgreSQL 16 con migraciones Alembic y triggers en PL/pgSQL.
* **Workers & OCR:** Subproceso aislado `ProcessPoolExecutor` (contexto `spawn`), pdfplumber y Tesseract 5 a 200 DPI con terminación forzosa (`SIGKILL`) ante timeouts.
* **Cola y Schedulers:** Patrón Outbox transaccional sobre PostgreSQL con Fencing Token y APScheduler.
* **Seguridad:** Criptografía Argon2id fuera del event loop, OTP con HMAC-SHA256, Rate Limiting con LRU acotado en memoria, y aislamiento anti-PII en logs.
