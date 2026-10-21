# Registro de Actualizaciones - Sprint 1 (SIGAD)

Este documento registra de forma secuencial y acumulativa (Append-Only) todos los cambios, nuevas características, refactorizaciones y correcciones desarrolladas a lo largo de la rama `Sprint1`.

---

## [Sprint 1.0.0] - 2026-10-21
### Inicialización de la Rama Sprint 1 sobre Base Consolidada de Main
- **Línea Base del Sistema:**
  - Creación de la rama `Sprint1` a partir de `main`, incorporando la arquitectura consolidada de la versión 2.0.7:
    - Backend robusto con FastAPI, PostgreSQL y Alembic.
    - Worker asíncrono de procesamiento OCR y extracción documental.
    - Cliente unificado Flutter (Web y Móvil) con carga perezosa de vistas y gestión reactiva con `flutter_bloc`.
    - Infraestructura orquestada con Docker Compose y Caddy con directivas anti-caché.
- **Configuración de Trazabilidad e Historial:**
  - Apertura del registro de cambios dedicado `docs/UpdatesSprint1.md` para auditar el ciclo de vida, historias de usuario y entregables desarrollados exclusivamente dentro de este sprint.

---

## [Sprint 1.1.0] - 2026-10-21
### Fase 1: Sesiones con Refresh Token Rotatorio y Detección de Reutilización (HU-01)
- **Persistencia de Sesiones y Familias de Tokens:**
  - Implementación del servicio `sesion_service.py` con emisión criptográfica de sesiones persistidas en la tabla `sesiones_auth`.
  - Generación de `jti` único por sesión y vinculación a familias de tokens mediante `family_id` (UUIDv4) tanto en login (`POST /api/v1/auth/login`) como en vinculación de clientes (`POST /api/v1/auth/vincular-cliente`).
  - Hashing seguro y veloz de refresh tokens mediante SHA-256 (`hash_refresh_token`).
- **Rotación y Detección de Reutilización (Token Reuse Detection - RFC 6749):**
  - Implementación de `POST /api/v1/auth/refresh` con rotación estricta: revocación del token previo y emisión de un nuevo par de tokens preservando el `family_id`.
  - Invalidador preventivo de toda la familia de tokens en caso de intento de reutilización de un refresh token revocado.
  - Rate limiting dedicado para el endpoint `refresh` con mensaje uniforme genérico contra enumeración de sesiones (`"Sesión inválida o expirada."`).
- **Revocación e Invalidez de Sesiones (Logout):**
  - Implementación del endpoint `POST /api/v1/auth/logout` que revoca de forma idempotente toda la familia de tokens asociada al refresh token presentado.
- **Contrato OpenAPI y Verificación Integral:**
  - Regeneración y sincronización de `openapi.json` con los nuevos endpoints y el esquema estricto `RefreshRequest`.
  - Creación y superación de la suite de pruebas de integración `backend/tests/integration/test_refresh_rotation.py` (5 pruebas pasando al 100%).

---

## [Sprint 1.2.0] - 2026-10-21
### Fase 2: Núcleo de Aplicación Flutter, Enrutamiento con Guards y Componentes Compartidos (HU-02)
- **Interceptor de Tokens y Manejo de Sesión Expirada (T2.1):**
  - Incorporación de constantes `authRefresh` y `authLogout` en `ApiEndpoints`.
  - Ampliación de `SessionVault` con `getRefreshToken()` y `updateTokens({access, refresh})` para sincronización en memoria y almacenamiento seguro.
  - Creación del stream global reactivo `SessionEvents.onExpired` para desacoplar la capa de transporte HTTP del gestor de estado.
  - Implementación de interceptor automático de 401 en `ApiClient` con mecanismo anti-estampida (`_refreshInFlight`), reintento transparente de peticiones y notificación centralizada de expiración.
  - Vinculación en `AuthBloc` para despachar `SessionExpired` y llamada idempotente a `POST /api/v1/auth/logout` antes de limpiar la sesión.
- **Enrutamiento Nombrado y Guardias de Seguridad (T2.2):**
  - Centralización de rutas en `AppRoutes` (`/`, `/login`, `/activar`, `/panel`, `/app`).
  - Creación del widget `AuthGuard` para protección declarativa de rutas basadas en capacidades (`AppCapability`), redirigiendo a login ante ausencia de sesión y mostrando `ErrorView` ("Acceso denegado") ante permisos insuficientes.
  - Enrutador desacoplado `AppRouter.onGenerateRoute` con `GlobalKey<NavigatorState>` y listener global en `MaterialApp` para navegación inmediata y feedback con `SnackBar` en caso de sesión caducada.
  - Migración de `SplashScreen` a navegación por rutas nombradas.
- **Componentes Compartidos Reutilizables (T2.3):**
  - Implementación de `SigadDataTable<T>` con soporte para columnas parametrizadas, estados de carga, vistas vacías personalizadas y barra de paginación integral con límites y offsets.
  - Creación de `SigadTextField`, `SigadFormDialog` (con captura asíncrona de errores sin cierre prematuro de modal) y `showSigadConfirm`.
  - Migración de `ClientsDataTable` para operar sobre `SigadDataTable`.
- **Estrategia de Despliegue Web y Verificación en Navegadores (T2.4):**
  - Documentación en `README.md` del comando de compilación web de producción `--no-web-resources-cdn` para garantizar aislamiento bajo Content Security Policy estricta (`default-src 'self'`).
  - Creación de la plantilla de auditoría manual `docs/verificacion-navegadores.md` para Chrome, Firefox y Safari.

---

## [Sprint 1.3.0] - 2026-10-21
### Fase 3: Gestión Integral de Clientes Asegurados (HU-03 / SGD-59 a SGD-64)
- **Capa Base de Repositorios y Servicios de Dominio (T3.1):**
  - Implementación de `BaseRepository[T]` genérico con operaciones CRUD, ordenamiento configurable y paginación.
  - Creación de `ClienteRepository` encapsulando búsqueda insensible a mayúsculas/minúsculas (ILIKE) por nombre e identificación.
  - Implementación de `ClienteService` centralizando la emisión de códigos OTP con HMAC-SHA256, actualización de contactos y verificación de dependencias de negocio.
  - Registro de excepciones de dominio en `handlers.py` (`RecursoNoEncontradoException` -> 404, `IdentificacionDuplicadaException` -> 409, `ConflictoDominioException` -> 409).
- **Validación Formal de RUC Ecuatoriano y Operaciones CRUD (T3.2):**
  - Implementación de validadores de RUC según estándar del SRI en Python (`validar_ruc_ecuatoriano` y `validar_identificacion` en `backend/app/schemas/cliente.py`) y Dart (`lib/core/utils/ecuadorian_id_validator.dart`), cubriendo personas naturales, sociedades públicas y sociedades privadas/extranjeras.
  - Admisión de cédula o RUC en `ClienteCreate.identificacion` y en formularios Flutter.
  - Adición de endpoints `PATCH /api/v1/clientes/{cliente_id}` (ADMIN y AGENTE, sin permitir modificación de identificación) y `DELETE /api/v1/clientes/{cliente_id}` (exclusivo ADMIN, impidiendo eliminación si existen pólizas o vehículos vinculados con HTTP 409).
  - Retorno HTTP 409 genérico en caso de identificación duplicada sin filtrar PII en el detalle de respuesta.
- **Listado Paginado Server-Side y Contrato OpenAPI (T3.3):**
  - Creación del esquema estándar `PaginatedResponse[T]` en `backend/app/schemas/base.py`.
  - Migración de `GET /api/v1/clientes` a paginación server-side con parámetros `q`, `skip` y `limit`.
  - Actualización de `ClientsRepository.getClients` en Flutter devolviendo `PaginatedClients` y sincronización de consumidores (`PoliciesTabView`, `OcrTabView`).
  - Regeneración y exportación hermética de `openapi.json`.
- **Interfaz de Usuario y Gestión Integral en Web Dashboard (T3.4):**
  - Implementación de búsqueda con debounce de 400 ms en `ClientsTabView`.
  - Paginación dinámica y visualización reactiva con `SigadDataTable`.
  - Incorporación de acciones de edición y eliminación con confirmación destructiva modal `showSigadConfirm`.
  - Control de acceso por capacidades en filas mediante `AppCapability.editClients` y `AppCapability.deleteClients`.
- **Pruebas Automatizadas de Integración y Widgets (T3.5 & T3.6):**
  - Suite de integración backend `backend/tests/integration/test_clientes_api.py` (15 pruebas cubriendo tipos de RUC, unicidad 409, paginación, búsqueda parcial, actualización, eliminación y restricciones de rol).
  - Suite de widgets para autenticación `test/features/auth/login_page_test.dart` (5 pruebas cubriendo renderizado, validación de formularios, despacho de `LoginSubmitted`, manejo de errores y redirección exitosa).
  - Suite de widgets para clientes `test/features/web_dashboard/client_form_dialog_test.dart` (5 pruebas cubriendo creación, validación de formato, edición con identificación de solo lectura y emisión de `CreateClientRequest` / `UpdateClientRequest`).---

## [Sprint 1.4.0] - 2026-10-21
### Fase 4: Gestión y Validación de Vehículos Asegurados (HU-04 / SGD-65 a SGD-68)
- **Extensión de Modelo y Esquema de Vehículos (T4.1):**
  - Migración de Alembic `0008_vehiculos_motor_chasis_color` agregando columnas `motor`, `chasis` y `color` a la tabla `vehiculos`.
  - Creación del índice único `ux_vehiculos_chasis` sobre `chasis` con restricción de unicidad estricta.
  - Actualización de esquemas Pydantic `VehiculoCreate`, `VehiculoUpdate` y `VehiculoResponse`.
  - Implementación del endpoint `PATCH /api/v1/vehiculos/{vehiculo_id}` con soporte para actualizar marca, modelo, anio, color, motor y chasis.
  - Retorno HTTP 409 con mensaje genérico ante colisión o duplicidad de placa o chasis.
- **Validación y Clasificación de Placas Ecuatorianas ANT (T4.2):**
  - Implementación en Python y Dart de las reglas oficiales de la Agencia Nacional de Tránsito (ANT):
    - Placas de autos (3 letras - 3 o 4 dígitos): primera letra representa provincia emisora; segunda letra clasifica el tipo de servicio (A, U, Z -> SERVICIO_PUBLICO; E, X, M, S -> GUBERNAMENTAL; otras -> PARTICULAR).
    - Placas de motos (2 letras - 3 o 4 dígitos/letras): clasificadas como MOTO.
  - Suite de pruebas exhaustivas `backend/tests/unit/test_plates.py` y `test/core/utils/ecuadorian_plate_validator_test.dart` cubriendo particiones de equivalencia, fronteras y letras de excepción.
- **Listado por Cliente y Diálogos de Gestión en Flutter (T4.3):**
  - Implementación de `GET /api/v1/vehiculos?cliente_id=` con filtrado eficiente en base de datos.
  - Creación de `VehiclesRepository` en Flutter consumiendo la API de vehículos.
  - Creación de `VehicleFormDialog` con validación reactiva de placas ANT, tipos de vehículo y campos extendidos (motor, chasis, color).
  - Creación del modal `ClientVehiclesDialog` permitiendo listar, registrar y editar vehículos asociados directamente desde la tabla de clientes (`ClientsDataTable`).
  - Pruebas de widgets `test/features/web_dashboard/vehicle_form_dialog_test.dart` superadas con éxito.
- **Protección de Datos y Respuestas 404 Uniformes (T4.4):**
  - Homogeneización de respuestas de seguridad: retorno estricto de HTTP 404 con mensaje uniforme `"Recurso no encontrado."` ante identificadores inexistentes o pertenecientes a otros clientes u organizaciones en endpoints de vehículos, clientes, pólizas, documentos y pagos.
  - Mitigación completa de riesgos de enumeración de recursos y filtración de información entre tenants o roles.
  - Suite de integración `backend/tests/integration/test_recursos_ajenos_404.py` superada con 6/6 pruebas.

---

## [Sprint 1.5.0] - 2026-10-21
### Fase 5: Infraestructura, Despliegue y Pipeline de CI (HU-05 / SGD-69, 70, 73–76, 80)
- **Imagen OCI Oficial y Configuración de Docker Compose (T5.1):**
  - Parametrización de imagen `${SIGAD_IMAGE:-ghcr.io/xavih830/sigadbackend}:${SIGAD_TAG:-latest}` para los servicios `api` y `worker` en `docker-compose.yml`.
  - Incorporación de etiquetas Open Containers Initiative (OCI) `org.opencontainers.image.source` y `org.opencontainers.image.title="sigadbackend"` en `Dockerfile`.
  - Variables de entorno comentadas añadidas a `.env.example`.
- **Caddy con TLS Automático y Soporte de Desarrollo (T5.2):**
  - Parametrización de Caddyfile con dominio configurable `{$SIGAD_DOMAIN:localhost}` y CA automática Let's Encrypt / interna mediante bloque global `{ email {$ACME_EMAIL:admin@localhost} }`.
  - Reutilización de configuración mediante snippet modular `(sigad_common)` importado en el bloque principal y en el bloque HTTP `:8085` para desarrollo local.
  - Validación sintáctica y estructural de Caddy mediante Docker (`caddy validate`).
- **Pipeline de Integración Continua Modular en GitHub Actions (T5.3):**
  - Reescritura integral de `.github/workflows/ci.yml` segregando responsabilidades en jobs independientes: `lint-backend`, `backend-test`, `export-openapi`, `generate-client`, `flutter-test` y `publish-ghcr`.
  - Adición de disparadores para ramas `main`, `v2`, `Sprint1` y tags `v*.*.*`.
  - Publicación automatizada de imágenes hacia GitHub Container Registry (GHCR) ante pushes a `main` o tags semánticos.
  - Saneamiento completo de estilo y calidad de código con Ruff (`ruff check backend`).
- **Convenciones de Repositorio y Gobernanza (T5.4):**
  - Creación de `docs/CONTRIBUTING.md` formalizando la convención de ramas (Git Flow), versionado semántico SemVer 2.0 (`vMAJOR.MINOR.PATCH`), commits convencionales atómicos vinculados a Jira, Definition of Ready (DoR) y Definition of Done (DoD).
  - Creación de la plantilla de Pull Requests `.github/pull_request_template.md`.
  - Vinculación de la guía de contribución desde `README.md`.
- **Exportación Aislada de OpenAPI sin Red ni Dependencia de Entorno (T5.5):**
  - Actualización de `backend/scripts/export_openapi.py` inyectando `_VARIABLES_FICTICIAS` defensivas para campos requeridos (`DATABASE_URL`, `JWT_SECRET_KEY`, `OTP_SECRET_KEY_*`, `SMTP_*`, etc.) y forzando `ENVIRONMENT="development"`.
  - Importación perezosa de `app.main:app` protegida bajo el gestor de contexto `defensive_socket_blocking`.
  - Suite de pruebas de aislamiento `backend/tests/unit/test_quality/test_openapi_export.py` con prueba de subproceso en directorio temporal aislado `test_export_sin_env_usa_variables_ficticias`.
- **Verificación Automatizada del Ciclo de Migraciones Alembic (T5.6):**
  - Inclusión del ciclo `alembic downgrade base && alembic upgrade head` en el pipeline de CI.
  - Creación de la prueba de integración `backend/tests/integration/test_migraciones_ciclo.py` (`@pytest.mark.migraciones`) validando la idempotencia y consistencia de tablas y tipos de catálogo (`rol_enum`) en ciclos completos de `downgrade base`, `upgrade head` y `downgrade -1`.

---

## [Sprint 1.6.0] - 2026-10-21
### Fase 6: Documentación Formal de Modelo de Pólizas (HU-06 / SGD-82)
- **Diccionario Unificado de Campos de Póliza (T6.1):**
  - Creación de `docs/campos-poliza.md` consolidando los campos de las tablas `polizas`, `vehiculos`, `coberturas`, `deducibles`, `inspecciones` y `esquemas_poliza`.
  - Documentación detallada por campo: nombre técnico, tabla, tipo de dato en base de datos, obligatoriedad, origen (fijo vs. dinámico), ejemplo representativo y columna de verificación para la Product Owner.
  - Registro de la sección "Pendiente de validar con la Product Owner" abordando tipificación de deducibles, catálogo de coberturas, obligatoriedad de inspecciones técnicas y reglas de validación en esquemas dinámicos.

---

## [Sprint 1.7.0] - 2026-10-21
### Cierre y Consolidación de Sprint 1: Estado de Historias y Auditoría Final
- **Historias de Usuario y Tareas Técnicas Cerradas Exitosamente:**
  - **HU-01: Autenticación y Rotación de Sesiones**
    - `SGD-54`: Sesiones persistidas y emisión criptográfica de refresh tokens con `family_id`.
    - `SGD-55`: Rotación estricta de refresh token y detección de reutilización conforme a RFC 6749.
    - `SGD-56`: Revocación explícita de sesiones (`POST /api/v1/auth/logout`) y rate limiting uniforme contra enumeración.
  - **HU-02: Núcleo de Aplicación Flutter, Enrutador y Componentes**
    - `SGD-57`: Interceptor HTTP automático en Flutter con reintento transparente, refresco concurrente protegido y notificación global de expiración.
    - `SGD-58`: Enrutador declarativo `AppRouter` con rutas nombradas, `AuthGuard` basado en capacidades de usuario y componentes compartidos `SigadDataTable`, `SigadTextField`, `SigadFormDialog` y `showSigadConfirm`.
  - **HU-03: Gestión Integral de Clientes Asegurados**
    - `SGD-59`: Capa de arquitectura limpia con `BaseRepository[T]`, `ClienteRepository`, `ClienteService` y desacoplamiento de excepciones de dominio.
    - `SGD-60`: Validador formal de RUC ecuatoriano (naturales, públicas, privadas/extranjeras) según normativa SRI en Python y Dart.
    - `SGD-61`: Endpoints CRUD completos (`POST`, `GET`, `PATCH`, `DELETE`) con validación de integridad referencial (409 ante vehículos o pólizas asociadas).
    - `SGD-62`: Paginación server-side con contrato OpenAPI hermético.
    - `SGD-63`: Interfaz de gestión en Flutter Web con búsqueda con debounce, paginación dinámica y modales de confirmación destructiva.
    - `SGD-64`: Suite completa de pruebas de integración en backend (15 pruebas) y pruebas de widgets en Flutter.
  - **HU-04: Gestión y Validación de Vehículos Asegurados**
    - `SGD-65`: Extensión de modelo con migración Alembic 0008 (`motor`, `chasis`, `color`), índice único de chasis y endpoint `PATCH`.
    - `SGD-66`: Reglas oficiales de la Agencia Nacional de Tránsito (ANT) para validación y tipificación de placas vehiculares en backend y Dart.
    - `SGD-67`: Diálogos modales en Flutter (`VehicleFormDialog`, `ClientVehiclesDialog`) para vinculación de vehículos desde la tabla de clientes.
    - `SGD-68`: Uniformidad de respuestas de seguridad HTTP 404 (`"Recurso no encontrado."`) mitigando enumeración o fugas de datos multitenant.
  - **HU-05: Infraestructura, Despliegue y Pipeline de CI**
    - `SGD-69`: Estandarización de imagen OCI para backend y parametrización en `docker-compose.yml`.
    - `SGD-70`: Configuración modular de Caddyfile con snippet común, dominio configurable, soporte TLS automático y puerto 8085 de desarrollo.
    - `SGD-73`: Pipeline de CI modular en GitHub Actions con jobs independientes (`lint-backend`, `backend-test`, `export-openapi`, `generate-client`, `flutter-test`, `publish-ghcr`).
    - `SGD-74`: Formalización de convenciones del repositorio en `docs/CONTRIBUTING.md` y plantilla de PR en `.github/pull_request_template.md`.
    - `SGD-75`: Script `export_openapi.py` hermético e independiente de red o variables de entorno reales.
    - `SGD-76`: Corrección y formateo con Ruff integrado en linting y pre-commit.
    - `SGD-80`: Pruebas de integración para ciclo de vida de migraciones Alembic (`downgrade base`, `upgrade head`, `downgrade -1`).
  - **HU-06: Documentación del Dominio de Pólizas**
    - `SGD-82`: Elaboración del diccionario formal de 51 campos de póliza y entidades relacionadas en `docs/campos-poliza.md`.
- **Verificación Técnica de Calidad y Suite Integral:**
  - Linter Ruff: 0 errores (`python -m ruff check backend`).
  - Linter Flutter: 0 advertencias (`flutter analyze`).
  - Suite de pruebas Flutter: 185 pruebas unitarias, de integración y de widgets superadas con éxito.
  - Contrato OpenAPI: Sincronizado sin diferencias de drift (`git diff --exit-code openapi.json`).
  - Infraestructura Docker: 5 servicios en ejecución y saludables (`sigad-api`, `sigad-caddy`, `sigad-postgres`, `sigad-mailpit`, `sigad-worker`), respondiendo en `https://localhost/health` y `http://localhost:8085/health`.
- **Tareas Pendientes de Decisión o Ejecución Humana (👤):**
  - `D1`: Confirmar la decisión de mantener el servicio propio de sesiones en lugar de adoptar la dependencia externa FastAPI-Users.
  - `D5`: Validar con la Product Owner la regla de clasificación de placas particulares vs. públicas por la segunda letra según especificación ANT.
  - `T2.4`: Ejecución de la lista de chequeo de compatibilidad visual en navegadores físicos (Chrome, Firefox, Safari) documentada en `docs/verificacion-navegadores.md`.
  - `T6.1`: Sesión de revisión con la Product Owner sobre el diccionario `docs/campos-poliza.md` (campos pendientes y dinámicos).
  - `Gobernanza`: Configurar las reglas de protección de rama en GitHub para `main` y verificar que el token de GitHub Actions disponga de permisos de escritura de paquetes (`packages: write`).
