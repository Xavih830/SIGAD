# Manifiesto de Evidencias — Midterm (Sprints 1 y 2)

> Generado el `2026-11-17` sobre la rama `Sprint2` (`3940a2b`).
> **Nota de alcance:** La docente indicó el `2026-11-17` que el pipeline de CI/CD no es necesario por ahora (`E1` retirada); las compuertas de calidad se ejecutaron localmente.

---

## 1. tags

| Tag | SHA Completo | Fecha | Mensaje |
|---|---|---|---|
| `v0.1.0` | `08b583593d3b1d78f34c49ceaca0d4020c5aac2f` | `2026-11-17` | `Sprint 1 increment` (sobre cierre histórico de `Sprint1`) |
| `v0.2.0` | `3940a2baa2c8f4cd95865458697c09792a3be4ef` | `2026-11-17` | `Sprint 2 increment` (sobre cierre de `Sprint2` con brechas `I*` y calidad `E4`) |

---

## 2. deployment

- **Ruta seleccionada:** Ruta A (Neon PostgreSQL + Render Docker Web Service + GitHub Pages Flutter Web).
- **Estado:** `[PENDIENTE DE EJECUCIÓN HUMANA]` — Requiere credenciales y paneles privados de Neon, Render y configuración de GitHub Pages en el navegador.
- **Preparación completada en el repositorio (`Sprint2`):**
  - `backend/app/core/config.py`: normalización automática de URLs Neon (`postgresql://` → `postgresql+asyncpg://`, `sslmode=require` → `ssl=require`, derivación automática de `DATABASE_SYNC_URL`) y origen `https://xavih830.github.io` en `CORS_ORIGINS`.
  - `Dockerfile`: arranque automático con `alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers ${UVICORN_WORKERS:-1}`.
  - `.github/workflows/deploy-gh-pages.yml`: workflow manual (`workflow_dispatch`) para publicar `build/web` en `gh-pages` con `--base-href "/SIGAD/"`.
- **URL de la web:** `[PENDIENTE: https://xavih830.github.io/SIGAD/]`
- **URL de la API:** `[PENDIENTE: https://<servicio>.onrender.com]`
- **Worker:** En la demo gratuita de Render (Ruta A) no se despliega un Background Worker separado; en staging/VM (`docs/staging.md`) corre como servicio independiente (`app.workers.worker_entrypoint`, límite `600M`).
- **Smoke check:** `[PENDIENTE]` — `EV-21` y `docs/informe/evidencias/smoke_<fecha>.txt` se generarán tras completar el despliegue manual en Neon/Render/GitHub Pages.

---

## 3. static_analysis

| Herramienta | Ruleset | Ref / SHA | Fecha | Total Hallazgos | Top 5 Reglas Más Frecuentes |
|---|---|---|---|---|---|
| `ruff` | Base (`pyproject.toml`) | `6ad85bf` (S1 inicio) | `2026-11-17` | `0` | — |
| `ruff` | Ampliado (`backend/ruff-extended.toml`) | `6ad85bf` (S1 inicio) | `2026-11-17` | `0` | — |
| `flutter analyze` | `analysis_options.yaml` | `6ad85bf` (S1 inicio) | `2026-11-17` | `0` | — |
| `ruff` | Base (`pyproject.toml`) | `08b5835` (`v0.1.0`, S1 cierre) | `2026-11-17` | `0` | — |
| `ruff` | Ampliado (`backend/ruff-extended.toml`) | `08b5835` (`v0.1.0`, S1 cierre) | `2026-11-17` | `39` | `PLR2004` (18), `PLC0415` (9), `PT006` (2), `SIM102` (1), `S106` (1) |
| `flutter analyze` | `analysis_options.yaml` | `08b5835` (`v0.1.0`, S1 cierre) | `2026-11-17` | `213` | `uri_does_not_exist` / `undefined_identifier` (faltaban utilidades base en snapshot de S1) |
| `ruff` | Base (`pyproject.toml`) | `fba9c7e` (S2 before) | `2026-11-17` | `0` | — |
| `ruff` | Ampliado (`backend/ruff-extended.toml`) | `fba9c7e` (S2 before) | `2026-11-17` | `167` | `PLC0415` (49), `PLR2004` (23), `PLR0913` (14), `S105` (13), `S311` (10) |
| `flutter analyze` | `analysis_options.yaml` | `32bae45` (S2 before) | `2026-11-17` | `0` | — |
| `ruff` | Base (`pyproject.toml`) | `f0d7dd9` (S2 after) | `2026-11-17` | `0` | — |
| `ruff` | Ampliado (`backend/ruff-extended.toml`) | `f0d7dd9` (S2 after) | `2026-11-17` | `140` | `PLC0415` (49), `PLR2004` (23), `PLR0913` (14), `S105` (13), `S311` (10) |
| `flutter analyze` | `analysis_options.yaml` | `f0d7dd9` (S2 after) | `2026-11-17` | `0` | — |

### Correcciones representativas (`f0d7dd9`, `3940a2b`)
1. **`RUF006` (dangling asyncio task) en `backend/app/workers/health.py`:**
   - *Antes:* `asyncio.create_task(server.serve())` (riesgo de recolección por GC).
   - *Después:* `task = asyncio.create_task(server.serve()); _background_tasks.add(task); task.add_done_callback(_background_tasks.discard)`.
2. **`S608` (SQL dinámico con f-string) en `backend/app/workers/watchdog.py`:**
   - *Antes:* `f"... WHEN intentos + 1 >= {MAX_OCR_FAILED_ATTEMPTS} ..."`
   - *Después:* `"... WHEN intentos + 1 >= :max_attempts ..."` con bind parameter `{"stale_minutes": str(stale_minutes), "max_attempts": MAX_OCR_FAILED_ATTEMPTS}`.
3. **`ASYNC240` (operación bloqueante en función `async`) en `backend/app/api/v1/endpoints/esquemas.py`:**
   - *Antes:* `if os.path.exists(tmp_path): os.unlink(tmp_path)`
   - *Después:* `await asyncio.to_thread(_cleanup_temp_file, tmp_path)`.

### Reglas aceptadas sin corregir y justificación
- `S101` en `tests/**`: `assert` es el mecanismo estándar de `pytest` (excluido en `ruff-extended.toml`).
- `PLR2004` en `tests/**`: valores numéricos literales en aserciones de pruebas (excluido en `ruff-extended.toml`).
- `PLR0913` en endpoints FastAPI: inyección de dependencias declarativa (`Depends(...)`) y parámetros de query incrementan la aridad por diseño del framework.
- `S105` / `S106` en fixtures y esquemas de prueba: credenciales sintéticas exclusivas para pruebas automatizadas locales.
- `PLC0415` en scripts/tests/lazy-imports: imports diferidos intencionales para aislamiento de módulos o pruebas de arquitectura.

---

## 4. tests

| Tag / Ref | Nivel | Ejecutadas | Aprobadas | Fallidas | Omitidas | Cobertura | Evidencia |
|---|---|---|---|---|---|---|---|
| `v0.2.0` (`3940a2b`) | Backend Unit (`tests/unit`) | `195` | `193` | `2` | `0` | `80%` global (`2523/3156` líneas) | `pytest_v0.2.0.xml`, `pytest_v0.2.0.txt`, `cov_v0.2.0/` |
| `v0.2.0` (`3940a2b`) | Backend Integration (`tests/integration`) | `137` | `135` | `2` | `0` (`1` deselected `migraciones`) | `80%` global | `pytest_v0.2.0.xml`, `pytest_v0.2.0.txt` |
| `v0.2.0` (`3940a2b`) | Flutter (`flutter test`) | `56` | `56` | `0` | `0` | `22.36%` (`1286/5752` líneas) | `flutter_v0.2.0.json`, `lcov_v0.2.0.info` |

**Detalle de fallos en corrida local de `v0.2.0` (4 de 332):**
- `tests/integration/test_smtp_mailpit.py` y `tests/integration/test_e2e_complete_universe.py`: requieren contenedor `mailpit` activo (entorno local corrió contra PostgreSQL en WSL sin Docker).
- `tests/unit/test_quality/test_architecture_config.py::test_client_env_example_has_no_backend_secrets` y `test_mechanical_guardrails.py::test_declarative_code_smells_compliance`: validan `.env.client.example` y `.agents/rules/code_smells_config.yml`, archivos pertenecientes a `main` y no incluidos en la rama `Sprint2`.

**Defectos encontrados y corregidos durante la ejecución:**
- `DEF-01` (Alembic): `revision = "0009_auditoria_clientes_y_version_polizas"` excedía `VARCHAR(32)` de `alembic_version.version_num` → corregido a `"0009_audit_clientes_polizas"` en `ecf3bfe`; ciclo `upgrade head` → `downgrade base` → `upgrade head` verificado en verde.
- `DEF-02` (Flutter tests): `test/flutter_test_config.dart` ausente en `Sprint2` provocaba fallo de `ApiConfig.baseUrl` en tests sin `--dart-define` → restaurado en `79fd7f3` (`56/56` pasando).
- `DEF-03` (Watchdog unit tests tras `S608`): aserciones de SQL literal en `test_outbox_watchdog_safe.py` y `test_watchdog_incrementa_intentos.py` → actualizadas en `3940a2b` (`2/2` pasando).

---

## 5. functional

| Caso | HU / AC | Entrada | Esperado | Obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| `FT-S1-01` | HU-01 | Login válido e inválido en web desplegada | Acceso con credenciales válidas y rechazo uniforme con inválidas | `[PENDIENTE]` (depende de E2) | `PENDING` | `EV-22` |
| `FT-S1-02` | HU-05 | `GET https://<api>/health` | `200 OK` `{"status":"ok","database":"connected"}` + cabeceras HTTPS | `[PENDIENTE]` (depende de E2) | `PENDING` | `EV-21` |
| `FT-S2-01` | HU-07 / AC-07-3 | `fecha_inicio=hoy`, `fecha_fin=+5 años` vs `+5 años +1 día` | Válida en `activa`; `+1 día` rechazada `422` | Validado en integración (`test_polizas_api.py`); pendiente en vivo (E2) | `PENDING_LIVE` | `EV-24` |
| `FT-S2-02` | HU-09 / AC-09-1/2 | Acción "Desactivar" y filtro `estado=cancelada` | Póliza pasa a `cancelada` sin borrarse y aparece al filtrar | Validado en integración (`test_polizas_update_historial.py`) y widget test (`policy_detail_and_table_test.dart`); pendiente en vivo (E2) | `PENDING_LIVE` | `EV-24` |
| `FT-S2-03` | HU-10 / AC-10-2 | `.exe` (`MZ...`) renombrado a `poliza.pdf` | Rechazo por magic bytes (`400`/`415`/`422`) | Validado en `test_documentos_api.py::test_subida_documento_mime_no_permitido_rechazado` (PASSED) | `PASS` | `pytest_v0.2.0.txt` |
| `FT-S2-04` | HU-11 / AC-11-1..4 | Póliza PDF real de ejemplo (H15) | Extracción y comparación de campos | `[PENDIENTE]` (depende de H15 y E2) | `PENDING` | — |
| `FT-S2-05` | HU-14 / AC-14-1/3 | Límites de memoria en compose + `EXPLAIN` de listados | Uso de índices (`Index Scan`) en pólizas, vehículos y documentos | `Index Scan` verificado en PostgreSQL (`ix_polizas_estado`, `ix_vehiculos_cliente_id`, `ix_documentos_poliza_id`) | `PASS` | `explain_*.txt`, `docs/staging.md` |

---

## 6. carried_over

| Tarea | HU / SGD | Estado | Fecha | SHA | Notas |
|---|---|---|---|---|---|
| `I1` | HU-08 / SGD-15 | Completada (carried over post-S2) | `2026-11-17` | `de4a32d`, `32bae45` | Migración `0009` (`usuario_id` en trigger, trigger en `clientes`, `version` en `polizas`), `PUT /api/v1/polizas/{id}` idempotente con `409` optimista, `GET /api/v1/polizas/{id}/historial`, UI 4 pestañas + botón Editar, pruebas integración y widget. |
| `I2` | HU-09 / SGD-16 | Completada (carried over post-S2) | `2026-11-17` | `de4a32d`, `32bae45` | Acción "Desactivar" en `PoliciesDataTable` con `showSigadConfirm`, filtro `?estado=` en `GET /polizas`, widget test y prueba de integración. |
| `I3` | HU-13 / SGD-20 | Completada (carried over post-S2) | `2026-11-17` | `f805898` | `PolizaRepositoryProtocol`, `PolizaRepository`, `PolizaService` inyectado por `Depends`, `InMemoryPolizaRepository` + unit tests sin BD, `docs/contratos-datos.md`. |
| `I4` | HU-14 / SGD-21 | Completada (carried over post-S2) | `2026-11-17` | `ecf3bfe` | `PIIRedactionFilter` en arranque de API y worker (`emails`, `cédulas`, `RUC`, `placas`), `test_logging_pii.py` ampliado, `docs/staging.md` y salidas `EXPLAIN`. |
| `I5` | HU-15 / SGD-22 | Pendiente (Humana — `H11`) | — | — | Requiere reunión real de inspección y firmas físicas. |
| `I6` | HU-10 / SGD-17 | Completada (carried over post-S2) | `2026-11-17` | `a02280a` | `test_subida_documento_mime_no_permitido_rechazado` y `test_subida_documento_magic_bytes_pdf_valido` en `test_documentos_api.py`. |

---

## 7. contributions

### Sprint 1 (`858a89c..v0.1.0`)
- `08b5835` Carlos Ronquillo Brush — `docs(sprint1): registrar bitacora de cambios consolidada del sprint 1`
- `81d0951` Steven Lino — `docs(polizas): documentar diccionario de campos de poliza para validacion con la po`
- `2956106` Cristhian Vinces Tapia — `test(db): verificar ciclo completo de upgrade y downgrade de migraciones`
- `30fe60d` Carlos Ronquillo Brush — `docs: definir convencion de ramas tags semanticos plantilla de pr y definition of ready`
- `a4a5835` Cristhian Vinces Tapia — `ci: separar jobs de lint openapi y drift de cliente y publicar imagen en ghcr`
- `8c45c89` Steven Lino — `fix(openapi): exportar contrato con variables ficticias sin depender de env ni red`
- `fd19b0a` Cristhian Vinces Tapia — `feat(ingress): habilitar tls automatico en caddy por dominio configurable`
- `7e7a645` Cristhian Vinces Tapia — `chore(docker): nombrar la imagen del backend como sigadbackend publicable en ghcr`
- `e6e2a1f` Xavier Camacho Galarza — `fix(seguridad): responder 404 uniforme ante recursos ajenos o inexistentes`
- `3a8c8bb` Manuel Matute Fernández — `feat(ui): agregar registro y listado de vehiculos por cliente`
- `019e709` Carlos Ronquillo Brush — `feat(vehiculos): clasificar placas ant por tipo y cubrir particiones de equivalencia`
- `fd98100` Carlos Ronquillo Brush — `feat(vehiculos): validar motor chasis y color y permitir actualizacion parcial`
- `25e5750` Carlos Ronquillo Brush — `feat(db): agregar motor chasis y color a vehiculos con indice unico de chasis`
- `83ae33c` Carlos Ronquillo Brush — `test(clientes): cubrir unicidad de identificacion busqueda paginacion y crud`
- `3b594b8` Manuel Matute Fernández — `feat(ui): listado paginado de clientes con busqueda en servidor edicion y eliminacion`
- `afa056f` Carlos Ronquillo Brush — `feat(clientes): agregar actualizacion y eliminacion de clientes con unicidad 409`
- `753680c` Carlos Ronquillo Brush — `feat(clientes): aceptar ruc ecuatoriano ademas de cedula en la identificacion`
- `3dd3acc` Xavier Camacho Galarza — `refactor(clientes): introducir capa base de repositorios y servicio de clientes`
- `fcab874` Leonardo David Macías Arturo — `docs(web): documentar build web con canvaskit local y checklist de navegadores`
- `55beb3b` Manuel Matute Fernández — `test(ui): agregar pruebas de widgets para login y validacion de errores`
- `d98419d` Manuel Matute Fernández — `feat(auth): construir pantalla de inicio de sesion web en flutter`
- `4c682dc` Manuel Matute Fernández — `feat(shared): crear componentes reutilizables de tabla paginada formularios y dialogos`
- `d5d8cb6` Leonardo David Macías Arturo — `feat(routing): introducir rutas nombradas con guard de autenticacion y redireccion`
- `bdf6e48` Leonardo David Macías Arturo — `feat(network): agregar interceptor de refresh de tokens y notificacion de sesion expirada`
- `bbc5940` Carlos Ronquillo Brush — `test(auth): agregar pruebas de rotacion y revocacion de familias de refresh`
- `3d559a5` Steven Lino — `feat(auth): implementar rotacion de refresh token con deteccion de reutilizacion y logout`
- `b07cd05` Steven Lino — `feat(auth): persistir sesiones con familia de refresh tokens en login y vinculacion`
- `6ad85bf` Xavier Camacho Galarza — `chore(base): estructurar proyecto Flutter y configuracion base de backend`

### Sprint 2 + Carried Over (`v0.1.0..v0.2.0`)
- `3940a2b` Xavih830 — `test(workers): alinear aserciones de watchdog con consulta parametrizada S608`
- `79fd7f3` Xavih830 — `test(flutter): restaurar flutter_test_config para pruebas sin dart-define`
- `f0d7dd9` Xavih830 — `refactor(calidad): corregir hallazgos de ruff ampliado en control de flujo async y sql`
- `fba9c7e` Xavih830 — `chore(calidad): versionar ruleset ampliado de ruff`
- `32bae45` Xavih830 — `fix(ui): corregir parametros de confirmacion y coberturas en edicion de polizas`
- `a02280a` Xavih830 — `test(documentos): probar rechazo por magic bytes y restaurar fixtures de integracion`
- `ecf3bfe` Xavih830 — `feat(observabilidad): agregar filtro PII en origen y documentar staging e indices`
- `f805898` Xavih830 — `refactor(polizas): desacoplar PolizaService con PolizaRepositoryProtocol y documentar contratos`
- `de4a32d` Xavih830 — `feat(polizas): implementar modificacion idempotente con historial y accion desactivar`
- `9a3d795` Xavih830 — `chore(git): ignorar caches python archivos de ide y documentos locales`
- `5bd3361` Xavih830 — `chore(git): remover archivos .pyc cacheados del seguimiento`
- `3d926bd` Xavih830 — `chore(deploy): habilitar soporte de neon render y github pages en sprint 2`
- `e0d871a` Carlos Ronquillo Brush — `docs(inspecciones): registrar primera inspeccion formal ieee 1028 sobre modulos criticos`
- `5ccee55` Cristhian Vinces Tapia — `chore(staging): aprovisionar entorno de staging con seeder postgresql y structlog sin PII`
- `d5f8b18` Manuel Matute Fernández — `feat(ui): implementar pestana y dialogo de creacion de esquemas vehiculares`
- `938c599` Steven Lino — `feat(schemas): incorporar modelo y presets semanticos de extraccion OCR`
- `485b3f6` Carlos Ronquillo Brush — `test(ocr): probar test_pool_kill_workers y recuperacion de memoria en resilient pool`
- `0e56e73` Steven Lino — `feat(ocr): implementar ResilientProcessPool con spawn terminacion forzosa y recreacion`
- `dc94df2` Carlos Ronquillo Brush — `feat(ocr): implementar compuerta de extraccion con pdfplumber y tesseract a 200 dpi`
- `7dcf70c` Xavier Camacho Galarza — `feat(documentos): implementar descarga protegida con verificacion de propietario y 404 anti-idor`
- `60bac57` Steven Lino — `feat(documentos): implementar endpoint de subida con limites validacion magic bytes y StorageService`
- `30c3ae8` Leonardo David Macías Arturo — `feat(ui): agregar accion de desactivar en la lista de polizas de Flutter`
- `e60e725` Cristhian Vinces Tapia — `feat(polizas): implementar cancelacion logica de polizas y su efecto en los listados`
- `f01b907` Leonardo David Macías Arturo — `feat(ui): construir vista de detalle administrativo con datos coberturas e historial`
- `e842e66` Xavier Camacho Galarza — `feat(polizas): implementar endpoint PUT de polizas con idempotencia y control de version`
- `9853eef` Cristhian Vinces Tapia — `feat(db): crear triggers de auditoria de PostgreSQL en polizas clientes y vehiculos`
- `745ba0a` Carlos Ronquillo Brush — `test(polizas): probar valores limite de vigencia con ano bisiesto y poliza vencida`
- `543c881` Manuel Matute Fernández — `test(polizas): probar cuatro caminos independientes del CFG y analisis def-use`
- `4881061` Manuel Matute Fernández — `feat(ui): construir lista de polizas con filtros por tipo de vigencia y estado`
- `11026aa` Manuel Matute Fernández — `feat(ui): construir formulario de registro de poliza con coberturas vehiculares`
- `8e734a0` Xavier Camacho Galarza — `feat(polizas): implementar endpoint POST de polizas con coberturas y datos financieros`
- `894e794` Xavier Camacho Galarza — `feat(polizas): implementar validar_y_calcular_estado_inicial y FechaInvalidaException`

---

## 8. evidence_register

| ID | Sprint | Artifact | Date | Branch/tag & SHA | Report section | File |
|---|---|---|---|---|---|---|
| `EV-01` | Sprint 1 | `docker-compose.yml` (servicios, límites, healthchecks) | `2026-11-17` | `v0.1.0` (`08b5835`) | 2, B | `docs/informe/img/EV-01_docker_compose.png` |
| `EV-02` | Sprint 1 | `Caddyfile` (TLS y cabeceras) | `2026-11-17` | `v0.1.0` (`08b5835`) | 2 | `docs/informe/img/EV-02_caddyfile.png` |
| `EV-03` | Sprint 1 | `sesion_service.py`: rotación y detección de reutilización | `2026-11-17` | `v0.2.0` (`3940a2b`) | 2 | `docs/informe/img/EV-03_sesion_service.png` |
| `EV-04` | Sprint 2 | `poliza_evaluator.py`: los 4 caminos del CFG | `2026-11-17` | `v0.2.0` (`3940a2b`) | 4 | `docs/informe/img/EV-04_poliza_evaluator.png` |
| `EV-05` | Sprint 1 | `schemas/vehiculo.py`: `clasificar_placa` (particiones) | `2026-11-17` | `v0.2.0` (`3940a2b`) | 4 | `docs/informe/img/EV-05_clasificar_placa.png` |
| `EV-06` | Sprint 2 | `resilient_pool.py`: spawn + SIGKILL | `2026-11-17` | `v0.2.0` (`3940a2b`) | 2 | `docs/informe/img/EV-06_resilient_pool.png` |
| `EV-08` | Sprint 1 | `ruff check` S1 inicio | `2026-11-17` | `6ad85bf` | 5 | `docs/informe/img/EV-08_ruff_s1_inicio.png` |
| `EV-09` | Sprint 1 | `ruff check --config ruff-extended.toml` S1 cierre | `2026-11-17` | `v0.1.0` (`08b5835`) | 5 | `docs/informe/img/EV-09_ruff_s1_cierre.png` |
| `EV-10` | Sprint 2 | `ruff check --config ruff-extended.toml` S2 before | `2026-11-17` | `fba9c7e` | 5 | `docs/informe/img/EV-10_ruff_s2_before.png` |
| `EV-11` | Sprint 2 | `ruff check --config ruff-extended.toml` S2 after | `2026-11-17` | `f0d7dd9` | 5 | `docs/informe/evidencias/ruff_s2_after_ext.txt` / `docs/informe/img/EV-11_ruff_s2_after.png` |
| `EV-12` | Sprint 1 | `flutter analyze` S1 cierre | `2026-11-17` | `v0.1.0` (`08b5835`) | 5 | `docs/informe/img/EV-12_flutter_analyze_s1.png` |
| `EV-13` | Sprint 2 | `flutter analyze` S2 after | `2026-11-17` | `v0.2.0` (`3940a2b`) | 5 | `docs/informe/img/EV-13_flutter_analyze_s2.png` |
| `EV-15` | Sprint 2 | Resumen de `pytest` para `v0.2.0` | `2026-11-17` | `v0.2.0` (`3940a2b`) | 6 | `docs/informe/img/EV-15_pytest_v0.2.0.png` |
| `EV-16` | Sprint 2 | Reporte HTML de cobertura (`cov_v0.2.0`) | `2026-11-17` | `v0.2.0` (`3940a2b`) | 6 | `docs/informe/img/EV-16_coverage_html.png` |
| `EV-17` | Sprint 2 | Resumen de `flutter test` (`56/56`) | `2026-11-17` | `v0.2.0` (`3940a2b`) | 6 | `docs/informe/img/EV-17_flutter_test.png` |
| `EV-21` | Sprint 2 | Smoke check `/health` del despliegue | `[PENDIENTE]` | — | 3, B | `docs/informe/img/EV-21_smoke_health.png` |
| `EV-22..25` | Sprint 2 | Web desplegada (login, clientes, póliza, detalle) | `[PENDIENTE]` | — | 3, 6 | — |
| `EV-26` | Sprint 2 | `git log --oneline v0.1.0..v0.2.0` con autores | `2026-11-17` | `v0.2.0` (`3940a2b`) | 3, 9 | `docs/informe/img/EV-26_git_log_s2.png` |

---

## 9. Pendientes Humanos (`H1`–`H16`)

| # | Pendiente | Sección | Estado |
|---|---|---|---|
| `H1` | Número de equipo y renombrar el repositorio a `T<n>` | Portada | `PENDING` |
| `H2` | Matriz de riesgos del curso anterior (SE I) | 4 | `PENDING` |
| `H3` | Formularios de aceptación firmados por la PO, Sprints 1 y 2 | 3, 8 | `PENDING` |
| `H4` | Carpeta Communications con índice | 8 | `PENDING` |
| `H5` | Capturas de Jira: backlog, board de cada sprint, sprint report, burndown; URL del tablero | 3 | `PENDING` |
| `H6` | Roles SCRUM por integrante, responsables de pruebas y enlace a la planificación | 3, 4, 9 | `PENDING` |
| `H7` | Reflexiones individuales | 9 | `PENDING` |
| `H8` | Enlace al video de la presentación | 11 | `PENDING` |
| `H9` | Confirmar a quién pertenece la cuenta `Xavih830` | 9 | `PENDING` |
| `H10` | Confirmar el uso de herramientas de IA y quién revisó qué | 10 | `PENDING` |
| `H11` | Firmas reales y fechas correctas en las actas de inspección | 3 (HU-15) | `PENDING` |
| `H12` | Export completo de las subtareas del Sprint 2 (HU-10 a HU-15) | 3, 5.2 | `PENDING` |
| `H13` | Respaldo escrito de que CI/CD no se exige en el midterm y reparto de sus 5 puntos | 7 | `PENDING` |
| `H14` | Criterios de aceptación originales del Sprint 1 desde Jira | 4, 5.1 | `PENDING` |
| `H15` | Una póliza PDF real de ejemplo (anonimizada) para la prueba funcional del lector | 6 | `PENDING` |
| `H16` | Corregir en Jira el estado de HU-08 y HU-13 (marcadas "Finalizada" sin código) y de SGD-73/76/77 (CI) | 3 | `PENDING` |
