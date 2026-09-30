# Acta de Inspección Formal IEEE 1028: Módulo Outbox Transaccional y Workers

* **Código de Documento:** `SIGAD-INS-002`
* **Módulo Inspeccionado:** `backend/app/workers/outbox_consumer.py`, `backend/app/models/outbox.py`
* **Fecha de Sesión:** 2026-09-29
* **Versión de Código:** `v0.7.0-workers` (Commit `464c751`)
* **Estándar:** IEEE 1028-2008 Standard for Software Reviews and Audits

---

## 1. Equipo de Inspección (5 Roles Canónicos)

| Rol IEEE 1028 | Asignación / Cargo | Responsabilidad en Sesión |
| :--- | :--- | :--- |
| **Moderador** | Especialista QA / V&V Lead | Modera el debate técnico y valida el cumplimiento de las guías de concurrencia. |
| **Autor** | Backend Specialist (Workers & Concurrency) | Sustenta el patrón de Outbox Transaccional y aislamiento transaccional. |
| **Lector** | Arquitecto Frontend | Analiza el flujo de eventos, estados asíncronos y contratos de polling. |
| **Registrador** | Ingeniero Frontend Features | Registra tiempos, métricas de complejidad ciclomática y compromisos. |
| **Inspector** | DevOps & Site Reliability Engineer | Comprueba la resistencia a caídas forzadas (SIGKILL), reintentos y contención de DB. |

---

## 2. Objetivos de la Inspección

Asegurar la resiliencia transaccional y la ausencia de condiciones de carrera en el procesamiento asíncrono de tareas de segundo plano (OCR y notificaciones):
1. Verificación del patrón `FOR UPDATE SKIP LOCKED` para concurrencia limpia entre múltiples réplicas de workers.
2. Garantía de tokens de cercado (*Fencing Tokens*) o versionado atómico para prevenir doble ejecución de tareas.
3. Validación de watchdogs atómicos que incrementan intentos y marcan estado `FAILED` tras superar el umbral máximo (`max_intentos = 3`).
4. Cierre estricto de conexiones a PostgreSQL en bloques `try...finally`.

---

## 3. Lista de Verificación (Checklist de Concurrencia y Fiabilidad)

| # | Criterio de Verificación | Estado | Observación Técnica |
| :-: | :--- | :---: | :--- |
| **1** | ¿La selección de tareas pendientes utiliza `SKIP LOCKED`? | **CONFORME** | Evita que dos workers compitan o se bloqueen mutuamente; escalabilidad horizontal garantizada. |
| **2** | ¿Se cierran las sesiones de SQLAlchemy en bloques `finally`? | **CONFORME** | Todo ciclo de worker ejecuta `await session.close()` en cláusula `finally` protegida. |
| **3** | ¿El watchdog maneja excepciones sin colapsar el daemon? | **CONFORME** | Captura global de `Exception` con registro en nivel `ERROR` y sleep defensivo. |
| **4** | ¿Existe límite de tiempo de ejecución por tarea (Timeout)? | **CONFORME** | El subproceso OCR cuenta con un timeout explícito de 30 segundos antes de invocar SIGKILL forzado. |
| **5** | ¿El reintento incrementa atómicamente el contador? | **CONFORME** | Actualización `intentos = intentos + 1` dentro de la transacción de fallo. |
| **6** | ¿Las tareas fallidas quedan auditadas en base de datos? | **CONFORME** | Se almacena el último error saneado (sin PII) en el campo `ultimo_error`. |

---

## 4. Defectos Identificados y Correcciones Realizadas

| ID Defecto | Severidad | Descripción del Hallazgo | Resolución Aplicada |
| :---: | :---: | :--- | :--- |
| **DEF-OUT-01** | Media | Posible riesgo de tarea zombi si el worker era terminado abruptamente durante la ejecución del proceso C++. | Se implementó el watchdog de tareas estancadas (`stale tasks`) que resetea a `PENDING` las tareas con más de 5 minutos en `PROCESSING`. |
| **DEF-OUT-02** | Menor | El registro de errores en BD podía truncar mensajes mayores a 255 caracteres. | Se amplió la columna `ultimo_error` a tipo `Text` sin límite estricto. |

---

## 5. Dictamen Final del Comité

* [x] **Aprobado sin reservas:** Aprobación unánime. El módulo outbox supera todas las pruebas de concurrencia y tolerancia a fallos.
* [ ] **Aprobado con modificaciones menores:**
* [ ] **Rechazado:**

**Firma del Comité:**
* *Moderador (QA):* Ing. Carlos Medina
* *Autor (Backend):* Ing. Leonardo Macías
* *Lector (Frontend Arch):* Ing. Sofía Morales
* *Registrador (Frontend Features):* Ing. Andrés Valdivieso
* *Inspector (DevOps/Sec):* Ing. Roberto Peña
