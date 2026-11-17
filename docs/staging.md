# Entorno de Staging y Verificación de Índices (SIGAD)

## 1. Servicios y Límites de Memoria

En el despliegue contenedorizado (`docker-compose.yml`), el entorno se compone de los cuatro servicios principales con los siguientes límites de recursos:

| Servicio | Imagen / Base | Límite de Memoria | Límite de CPU | Rol |
|---|---|---|---|---|
| `postgres` | `postgres:16-alpine` | `800M` | `1.0` | Base de datos relacional PostgreSQL 16 (pólizas, clientes, vehículos, outbox, auditoría). |
| `api` | `sigadbackend` (Python 3.11 + Uvicorn) | `400M` | `0.75` | API REST FastAPI, autenticación JWT/refresh rotatorio y validación de contratos. |
| `worker` | `sigadbackend` (`app.workers.worker_entrypoint`) | `600M` | `1.0` | Procesador asíncrono de documentos OCR (`ResilientProcessPool`, Tesseract, pdfplumber) y watchdog/scheduler. |
| `caddy` | `caddy:2-alpine` | `150M` | `0.5` | Reverse proxy TLS automático, cabeceras CSP/HSTS y servidor estático para Flutter Web. |

*(En la ruta gestionada de staging/demo sobre Render + Neon + GitHub Pages, `postgres` se aloja en Neon, `api` en un Web Service Docker de Render con 512 MB RAM y 1 worker Uvicorn, y la web estática en GitHub Pages).*

---

## 2. Redacción de PII en Logs

Tanto la API (`app/main.py`) como el worker (`app/workers/worker_entrypoint.py`) registran en el arranque `install_pii_redaction_filter()` (`app/core/logging_filter.py`), garantizando el enmascaramiento en origen de:
- Correos electrónicos (`[REDACTED_EMAIL]`)
- Cédulas de 10 dígitos (`[REDACTED_CEDULA]`) y RUC de 13 dígitos (`[REDACTED_RUC]`)
- Placas vehiculares (`[REDACTED_PLACA]`)
- Secretos, contraseñas y tokens Bearer (`[REDACTED_SECRET]`, `[REDACTED_TOKEN]`)

---

## 3. Verificación de Uso de Índices (`EXPLAIN`)

Las consultas frecuentes de listado utilizan los índices creados en las migraciones (`0001`–`0009`). Las salidas crudas se almacenan en:
- `docs/informe/evidencias/explain_polizas.txt` → `Index Scan using ix_polizas_estado on polizas`
- `docs/informe/evidencias/explain_vehiculos.txt` → `Index Scan using ix_vehiculos_cliente_id on vehiculos`
- `docs/informe/evidencias/explain_documentos.txt` → `Index Scan using ix_documentos_poliza_id on documentos`
