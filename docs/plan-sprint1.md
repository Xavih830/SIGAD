# Plan de ejecución — Sprint 1 (SIGAD)

> **Destinatario:** agente implementador (Gemini 3.8 Flash, esfuerzo medio).
> **Fuente:** exportación Jira del Sprint 1 (HU-01 a HU-06, subtareas SGD-48 a SGD-82).
> **Base revisada:** rama `v2`, commit `9e4643e` (2026-10-21).

Este plan contiene **solo lo que falta**. La sección 1 lista lo que ya existe en el código para que no lo vuelvas a implementar. Lee las secciones 0 y 1 completas antes de empezar.

---

## 0. Reglas obligatorias para el agente

1. **No reescribas lo que ya funciona.** Si una tarea dice "modificar", edita el archivo existente; no crees uno paralelo.
2. **Commits atómicos** según `README.md` §1: un commit por tarea (o por sub-paso indicado), formato `<tipo>(<alcance>): <descripción en imperativo>` en español. No hagas `push` ni crees PRs.
3. **Después de cada tarea** ejecuta las compuertas que correspondan y no avances si fallan:
   - Backend: `cd backend && PYTHONPATH=. pytest tests/ -q` (las pruebas de integración requieren PostgreSQL; levántalo con `docker compose up -d postgres`).
   - Flutter: `flutter analyze` y `flutter test` desde la raíz.
4. **Contrato OpenAPI:** cada vez que cambies un endpoint o un esquema Pydantic, regenera con `python backend/scripts/export_openapi.py` e incluye `openapi.json` en el mismo commit. Si cambias un esquema de respuesta, actualiza también el modelo Dart en `lib/core/models/` (el test `test_client_generation_drift.py` lo exige).
5. **Respeta los invariantes de seguridad existentes:** login en tiempo constante (`verify_dummy`), mensajes de error genéricos, logs sin PII (no registrar cédulas, emails ni contraseñas en tareas nuevas), `StrictBaseSchema` (`extra="forbid"`) para los payloads de entrada.
6. **Estilo:** sigue el estilo de los archivos vecinos (docstrings cortos, nombres en español para el dominio, `Mapped[...]` en SQLAlchemy 2.0, `package:sigad/...` en los imports de Dart).
7. **Bitácora:** al terminar cada fase, agrega una entrada al final de `docs/UpdatesSprint1.md` (solo se agrega al final, nunca se edita lo anterior), con el mismo formato que la entrada `[Sprint 1.0.0]`.
8. Si una prueba existente contradice este plan (por ejemplo, espera `400` donde el plan pide `409`), **actualiza la prueba** en el mismo commit y menciónalo en el mensaje del commit.

---

## 1. Estado actual (verificado en el código)

Leyenda: ✅ hecho · 🟡 parcial (la tarea del plan completa lo que falta) · ❌ falta · 👤 requiere intervención humana

| Jira | Subtarea | Estado | Evidencia / brecha |
|---|---|---|---|
| SGD-48 | EmailAuthBackend con FastAPI-Users, Argon2id, endpoint login | 🟡 | Login propio en `backend/app/api/v1/endpoints/auth.py` con Argon2id (`core/security.py`). No usa FastAPI-Users → ver **Decisión D1** |
| SGD-49 | Sesiones con refresh token rotatorio `jti` y `family_id` | 🟡 | El modelo `SesionAuth` y la tabla `sesiones_auth` existen, pero **no se usan**: no hay `/auth/refresh` ni `/auth/logout`, y el login no persiste la sesión → **T1.1** |
| SGD-50 | Pantalla de login web en Flutter con manejo de errores | ✅ | `lib/features/auth/presentation/pages/login_page.dart`, `lockout_view.dart` |
| SGD-51 | Probar login web y `test_argon2_no_event_loop_block` | 🟡 | Existen `test_argon2_no_event_loop_block.py`, `test_login_polimorfico.py`, `test_constant_time_login_structural.py`. Faltan las pruebas de refresh → **T1.1** |
| SGD-52 | Handler global de `SQLAlchemyError` (tipo, SQLSTATE, ruta) | ✅ | `backend/app/core/handlers.py` + `test_no_pii_in_sqlalchemy_logs.py` |
| SGD-53 | Cliente Dart con interceptor de tokens | 🟡 | `ApiClient` inyecta el bearer, pero `onUnauthorized` nunca se conecta y no hay refresh automático. No existe cliente *generado* → ver **D2** y **T2.1** |
| SGD-54 | Estructurar `lib/core` y `lib/shared` con tema, enrutamiento y estado | 🟡 | Tema (`app_theme.dart`) y BLoC listos. **No hay `lib/shared` ni enrutador**: la navegación es imperativa desde `SplashScreen` → **T2.2** |
| SGD-55 | Layout administrativo con barra lateral | ✅ | `web_dashboard_page.dart`, `dashboard_sidebar.dart`, `dashboard_tab_registry.dart` |
| SGD-56 | Componentes compartidos: tabla, formularios, diálogos | ❌ | Cada tabla y diálogo está hecho a mano por feature → **T2.3** |
| SGD-57 | Guards de rutas y manejo de sesión expirada | 🟡 | Hay `CapabilityGate` y el evento `SessionExpired` en `AuthBloc`, pero **nadie despacha `SessionExpired`** → **T2.1 + T2.2** |
| SGD-58 | Flutter Web con renderer JS; verificar Chrome, Firefox y Safari | 🟡👤 | CanvasKit se empaqueta localmente (commit `7aef775`). Ver **D3**; la verificación en navegadores es manual → **T2.4** |
| SGD-59 | CRUD de clientes con cédula o RUC única | 🟡 | Solo crear, listar y obtener. **Falta actualizar y eliminar. No se acepta RUC.** Un duplicado devuelve 400 → **T3.2** |
| SGD-60 | Pantalla de registro de cliente | 🟡 | `client_form_dialog.dart` existe; falta soporte de RUC y edición → **T3.4** |
| SGD-61 | Listado paginado de clientes con búsqueda | 🟡 | El backend acepta `q/skip/limit` pero no devuelve `total`. **La UI filtra en memoria y no pagina** → **T3.3 + T3.4** |
| SGD-62 | Probar unicidad de identificación y búsqueda | ❌ | No existe `test_clientes_api.py` → **T3.5** |
| SGD-63 | Widget tests de login y registro de cliente | ❌ | Solo hay pruebas de `AccountActivationPage` → **T3.6** |
| SGD-64 | Capa base de servicios y repositorios aplicada a clientes | ❌ | Los endpoints consultan la BD directamente; no existe `app/repositories/` → **T3.1** |
| SGD-65 | Endpoints de vehículos: placa ANT, motor, chasis, color | 🟡 | La placa ANT ya se valida. **No existen las columnas motor, chasis ni color** → **T4.1** |
| SGD-66 | Pantalla de registro de vehículo asociada a un cliente | ❌ | No hay repositorio ni formulario de vehículos en la UI → **T4.3** |
| SGD-67 | Particiones de equivalencia: placas particulares, motos, servicio público | 🟡 | `test_plates.py` cubre formatos, pero **no clasifica el tipo de placa** → **T4.2** |
| SGD-68 | 404 uniforme para vehículos y otros recursos ajenos | 🟡 | `GET /vehiculos/{id}` ya filtra por dueño, pero `POST /vehiculos` y `GET /clientes/{id}` responden **403** ante recursos ajenos → **T4.4** |
| SGD-69 | Imagen `sigadbackend` y docker-compose con límites, volúmenes y healthchecks | 🟡 | Límites, volúmenes y healthchecks ✅. **La imagen no se llama `sigadbackend`** → **T5.1** |
| SGD-70 | Caddy con TLS automático, proxy a la API y cabeceras | 🟡 | Proxy y cabeceras ✅. El sitio `:80, :443` **sin hostname no emite certificados** → **T5.2** |
| SGD-71 | Endpoint `/health` de la API que verifica PostgreSQL | ✅ | `backend/app/main.py` (`/health`, `/health/ready`, `/health/live`) + `test_health_probes.py` |
| SGD-72 | Proceso independiente del worker con su `/health` | ✅ | `app/workers/worker_entrypoint.py`, `app/workers/health.py`, servicio `worker` en compose |
| SGD-73 | GitHub Actions: ruff, pytest, flutter analyze, publicación en GHCR | 🟡 | pytest y flutter analyze ✅. **Faltan ruff y la publicación en GHCR; solo corre sobre `main`** → **T5.3** |
| SGD-74 | Convención de ramas, tags semánticos, plantilla de PR, Definition of Ready | ❌ | Solo existe la guía de commits del README → **T5.4** |
| SGD-75 | `export_openapi.py` con variables ficticias y bloqueo de socket | 🟡 | El bloqueo de socket ✅. **No inyecta variables ficticias**: falla si no hay `.env` → **T5.5** |
| SGD-76 | Jobs de CI `export-openapi` y `generate-client` con verificación de drift | 🟡 | El drift de OpenAPI es un *step* dentro de `backend-test`, no un job, y **no existe el job `generate-client`** → **T5.3** |
| SGD-77 | `test_openapi_export` y `test_openapi_drift` | ✅ | `backend/tests/unit/test_quality/` |
| SGD-78 | Modelos: usuarios, clientes, vehículos, inspecciones, pólizas, coberturas | ✅ | `backend/app/models/` |
| SGD-79 | Modelos: documentos, resultados de extracción, historial, sesiones, códigos | ✅ | `backend/app/models/` |
| SGD-80 | Migración inicial con enum e índices; verificar upgrade/downgrade | 🟡 | Migraciones `0001`–`0007` con `downgrade()`. **No hay una verificación automática del ciclo completo** → **T5.6** |
| SGD-81 | `test_kilometraje_snapshot` | ✅ | `backend/tests/integration/test_kilometraje_snapshot.py` |
| SGD-82 | Revisar las pólizas de ejemplo de la PO y fijar campos | 🟡👤 | Existen esquemas dinámicos (`0007_esquemas_poliza`). La validación con la PO es humana → **T6.1** (solo documentación) |

**Resumen:** de 35 subtareas, 9 están hechas, 20 parciales (2 de ellas requieren intervención humana) y 6 por hacer. Por historia, lo que más falta está en HU-03 (clientes), HU-04 (vehículos) y HU-05 (CI y despliegue).

---

## 2. Decisiones tomadas (no las cambies sin consultar)

- **D1 — FastAPI-Users:** **no se migra.** El login propio ya cumple Argon2id, el login por email o cédula, el tiempo constante y el rate limiting, y tiene pruebas estructurales. Migrar a FastAPI-Users rompería esos invariantes. SGD-48 se cierra con la implementación actual más el refresh de **T1.1**. *(Confirmar con el equipo; si exigen FastAPI-Users de forma literal, se abre una tarea aparte.)*
- **D2 — Cliente Dart "generado":** **no se introduce `openapi-generator`.** El proyecto mantiene modelos escritos a mano alineados con OpenAPI y protegidos por `test_client_generation_drift.py` (commit `96e973e`). El job `generate-client` de CI ejecuta esa verificación de drift.
- **D3 — Renderer web:** Flutter estable ya no tiene renderer HTML. Se mantiene **CanvasKit local** (necesario para la CSP actual). SGD-58 se cierra documentando el build y la verificación manual en navegadores.
- **D4 — Paginación:** las listas paginadas nuevas devuelven `{"items": [...], "total": N, "skip": S, "limit": L}` mediante un genérico `PaginatedResponse[T]`.
- **D5 — Clasificación de placas (confirmar con la PO):** la regla se basa en la **segunda letra** de las placas de 3 letras: `A`, `U`, `Z` → servicio público/comercial; `E`, `X`, `M`, `S` → gubernamental/oficial; cualquier otra → particular. Las placas de 2 letras son siempre motos.

---

## 3. Orden de ejecución

```
Fase 1 (auth backend) ──► Fase 2 (Flutter núcleo) ──► Fase 3 (clientes) ──► Fase 4 (vehículos)
Fase 5 (devops) puede ir en paralelo; T5.3 conviene hacerla al final para que ruff vea el código definitivo.
Fase 6 (documentación) al final.
```

Dentro de cada fase, sigue el orden numérico.

---

## Fase 1 — HU-01: sesiones con refresh rotatorio (SGD-48, 49, 51)

### T1.1 Refresh token rotatorio con `jti` y `family_id`

**Archivos:** `backend/app/core/security.py`, `backend/app/api/v1/endpoints/auth.py`, `backend/app/schemas/auth.py`, nuevo `backend/app/services/sesion_service.py`, nuevo `backend/tests/integration/test_refresh_rotation.py`.

**Pasos:**
1. En `security.py`, agrega `hash_refresh_token(token: str) -> str` con SHA-256 hex (`hashlib`). No uses Argon2 aquí: el token ya tiene alta entropía y el hash debe ser rápido.
2. Crea `sesion_service.py` con funciones async que reciben `AsyncSession`:
   - `emitir_sesion(db, usuario, family_id: uuid.UUID | None = None) -> tuple[str, str]`: genera `jti = uuid4()`, crea los tokens con `{"sub", "rol", "jti", "fid": str(family_id)}`, inserta `SesionAuth(usuario_id, family_id, jti, refresh_token_hash, expira_en = now + JWT_REFRESH_TOKEN_EXPIRE_DAYS)` y devuelve `(access, refresh)`. Si `family_id` es `None`, genera uno nuevo.
   - `rotar_sesion(db, refresh_token) -> tuple[Usuario, str, str]`:
     1. `decode_token`; exige `type == "refresh"`.
     2. Busca `SesionAuth` por `jti`.
     3. Si no existe, o `refresh_token_hash` no coincide, o `expira_en < now` → 401.
     4. **Si `revocado` es `True` (reutilización detectada):** marca `revocado=True` en **todas** las sesiones con ese `family_id`, hace commit, registra `logger.warning("refresh_reuse_detected family_id=%s", ...)` y responde 401.
     5. Si no: marca la sesión actual `revocado=True`, emite una nueva con el **mismo** `family_id` y hace commit.
   - `revocar_familia(db, refresh_token)`: para el logout; revoca la familia del token. Es idempotente y no falla si el token es inválido.
3. En `auth.py`:
   - `login` y `vincular_cliente`: reemplaza la creación manual de tokens por `emitir_sesion(...)` y haz commit.
   - Nuevo `POST /auth/refresh` (body `RefreshRequest {refresh_token: str}` con `StrictBaseSchema`, respuesta `TokenResponse`). Aplica `rate_limiter.check_ip(ip=..., endpoint="refresh")`; si el limitador exige registrar el endpoint, agrega la clave correspondiente en `core/rate_limit.py`/`constants.py` siguiendo el patrón de `"login"`.
   - Nuevo `POST /auth/logout` (body `RefreshRequest`, responde `204`).
   - Todos los 401 de refresh usan un único mensaje genérico: `"Sesión inválida o expirada."`.
4. No hace falta una migración: la tabla `sesiones_auth` ya tiene todas las columnas.
5. Pruebas en `test_refresh_rotation.py`, usando los fixtures y escenarios de `tests/factories/`:
   - Un login crea exactamente una fila en `sesiones_auth`.
   - Un refresh válido devuelve tokens nuevos con un `jti` distinto, revoca la sesión anterior y conserva el `family_id`.
   - Reutilizar un refresh ya rotado → 401 y **toda la familia queda revocada** (el refresh más reciente también falla).
   - Usar un access token en `/auth/refresh` → 401.
   - Un logout revoca la familia, y el refresh posterior → 401.
6. Regenera `openapi.json`.

**Criterios de aceptación:** las 5 pruebas pasan; `test_login_polimorfico.py` y `test_constant_time_login_structural.py` siguen pasando; ningún log nuevo incluye email ni cédula.

**Commits sugeridos:**
- `feat(auth): persistir sesiones con familia de refresh tokens en login y vinculacion`
- `feat(auth): implementar rotacion de refresh token con deteccion de reutilizacion y logout`
- `test(auth): agregar pruebas de rotacion y revocacion de familias de refresh`

---

## Fase 2 — HU-02: núcleo Flutter (SGD-53, 54, 56, 57, 58)

### T2.1 Interceptor de tokens con refresh y sesión expirada

**Archivos:** `lib/core/network/api_client.dart`, `lib/core/services/session_vault.dart`, `lib/core/constants/api_endpoints.dart`, nuevo `lib/core/network/session_events.dart`, `lib/features/auth/presentation/bloc/auth_bloc.dart`, pruebas en `test/api_client_test.dart`.

**Pasos:**
1. En `api_endpoints.dart`, agrega `authRefresh = '/api/v1/auth/refresh'` y `authLogout = '/api/v1/auth/logout'` (usa el mismo formato que las constantes existentes).
2. En `SessionVault`, agrega `static Future<String?> getRefreshToken()` y `static Future<void> updateTokens({required String access, required String refresh})`, que actualiza la sesión guardada y `_cachedAccessToken`. La sesión ya guarda `refresh_token` (ver `auth_bloc.dart` líneas ~70 y ~141).
3. Crea `session_events.dart` con un notificador global simple:
   ```dart
   class SessionEvents {
     static final StreamController<void> _expired = StreamController<void>.broadcast();
     static Stream<void> get onExpired => _expired.stream;
     static void notifyExpired() => _expired.add(null);
   }
   ```
4. En `ApiClient`:
   - Centraliza el envío en un método privado `_send(Future<http.Response> Function(Map<String,String> headers) request, ...)`.
   - Ante un **401** en una ruta que **no** sea `authLogin`, `authRefresh` ni `vinculacion`: llama una sola vez a `_tryRefresh()` (POST a `authRefresh` con el refresh guardado). Si responde 200, guarda los tokens con `SessionVault.updateTokens` y **reintenta la petición original una vez** con el token nuevo.
   - Usa un `static Future<bool>? _refreshInFlight` para que varias peticiones con 401 simultáneas compartan **un solo** refresh.
   - Si el refresh falla: `SessionVault.clearSession()`, `SessionEvents.notifyExpired()`, conserva la llamada a `onUnauthorized?.call()` y lanza `ApiException(401, 'Su sesión ha expirado. Inicie sesión nuevamente.')`.
   - Aplica lo mismo a la ruta multipart (línea ~249).
5. En `AuthBloc`, suscríbete a `SessionEvents.onExpired` en el constructor → `add(SessionExpired())`, y cancela la suscripción en `close()`. En `LogoutRequested`, llama a `authLogout` con el refresh (si falla, ignora el error **registrándolo con `debugPrint`**, sin silenciarlo) antes de limpiar el vault.
6. Pruebas con `MockClient` de `package:http/testing.dart`:
   - 401 → refresh OK → reintento OK → devuelve los datos.
   - 401 → refresh 401 → se emite `SessionEvents.onExpired` y se lanza `ApiException`.
   - Dos peticiones concurrentes con 401 → el endpoint de refresh se llama **una** sola vez.

**Commit:** `feat(network): agregar interceptor de refresh de tokens y notificacion de sesion expirada`

### T2.2 Enrutador con guards y estructura `lib/shared`

**Archivos:** nuevo `lib/core/routing/app_routes.dart`, nuevo `lib/core/routing/app_router.dart`, nuevo `lib/core/routing/auth_guard.dart`, `lib/main.dart`, `lib/features/mobile_client/presentation/pages/splash_screen.dart`.

**Decisión:** no agregues `go_router`. Usa `MaterialApp.onGenerateRoute` con un `navigatorKey` global, para no romper los tests que navegan con `Navigator`.

**Pasos:**
1. `app_routes.dart`: constantes `splash = '/'`, `login = '/login'`, `activacion = '/activar'`, `dashboard = '/panel'`, `mobile = '/app'`.
2. `auth_guard.dart`: widget `AuthGuard({required AppCapability capability, required Widget Function(UserModel) builder})`. Lee `AuthBloc`; si el estado no es `AuthSuccess` → redirige (post-frame) a `login`; si el usuario no tiene la capacidad (`AuthorizationPolicy.canUser`) → muestra `ErrorView` con "Acceso denegado".
3. `app_router.dart`: `static final navigatorKey = GlobalKey<NavigatorState>()` y `static Route<dynamic> onGenerateRoute(RouteSettings s)`, que mapea cada ruta a su página y envuelve `dashboard` en `AuthGuard(capability: AppCapability.accessWebDashboard, ...)`. Cualquier ruta desconocida va a `login`.
4. `main.dart`: `MaterialApp(navigatorKey: AppRouter.navigatorKey, onGenerateRoute: AppRouter.onGenerateRoute, initialRoute: AppRoutes.splash)`. Envuelve el `MaterialApp` en un `BlocListener<AuthBloc, AuthState>` que, cuando el estado pasa a sesión expirada o cerrada, haga `navigatorKey.currentState!.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false)` y muestre un `SnackBar` con "Su sesión ha expirado." solo si fue por expiración. Revisa en `auth_state.dart` cómo se representa la expiración y úsalo; si no hay un estado distinguible, agrega `AuthSessionExpired`.
5. `SplashScreen`: reemplaza los `pushReplacement` manuales por `pushReplacementNamed` hacia las rutas nuevas, con la misma lógica de decisión (web o móvil según la capacidad).
6. Crea la carpeta `lib/shared/widgets/` (se llena en T2.3). No muevas los archivos de `lib/core/widgets/`.
7. Prueba `test/routing/auth_guard_test.dart`: sin sesión, `/panel` termina en `LoginPage`; con un usuario sin capacidad, se ve "Acceso denegado".

**Commit:** `feat(routing): introducir rutas nombradas con guard de autenticacion y redireccion por sesion expirada`

### T2.3 Componentes compartidos de tabla, formularios y diálogos

**Archivos nuevos en `lib/shared/widgets/`:**
- `sigad_data_table.dart`: `SigadDataTable<T>` con `columns: List<SigadColumn<T>>` (`label`, `cellBuilder`), `rows: List<T>`, `isLoading`, `emptyMessage`, y una barra de paginación opcional (`total`, `skip`, `limit`, `onPageChanged(int newSkip)`) que muestra "Mostrando X–Y de N" con botones anterior/siguiente. Usa los colores de `AppTheme`.
- `sigad_text_field.dart`: `SigadTextField` sobre `TextFormField`, con `label`, `controller`, `validator`, `keyboardType`, `inputFormatters`, `textCapitalization` y estilo consistente.
- `sigad_form_dialog.dart`: `SigadFormDialog` con `title`, `child` (el formulario), `onSubmit` async, botón "Guardar" con spinner mientras envía y "Cancelar". Si `onSubmit` lanza una excepción, muestra el mensaje dentro del diálogo, sin cerrarlo.
- `sigad_confirm_dialog.dart`: `Future<bool> showSigadConfirm(context, {title, message, confirmLabel, destructive})`.

**Pasos:** crea los widgets; migra **solo** `ClientsDataTable` para que use `SigadDataTable` (los demás se migran en sprints futuros); agrega `test/shared/sigad_data_table_test.dart` (estado vacío, botones de paginación que llaman al callback).

**Commit:** `feat(shared): crear componentes reutilizables de tabla paginada formularios y dialogos`

### T2.4 Flutter Web: build documentado y checklist de navegadores (SGD-58)

1. Agrega a `README.md` una sección "4.1 Build web de producción" con `flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env.client` (verifica que el flag exista con `flutter build web -h`; si no existe, documenta el comando que ya se usa en el commit `7aef775`). Explica que CanvasKit se sirve localmente por la CSP.
2. Crea `docs/verificacion-navegadores.md` con una tabla para Chrome, Firefox y Safari (versión, fecha, login OK, dashboard OK, registro de cliente OK, sesión expirada OK, responsable) **vacía para llenarla a mano**.

**Commit:** `docs(web): documentar build web con canvaskit local y checklist de navegadores`

👤 *La verificación real en los tres navegadores la hace una persona.*

---

## Fase 3 — HU-03: clientes (SGD-59 a 64)

### T3.1 Capa base de repositorios y servicios (SGD-64)

**Archivos nuevos:** `backend/app/repositories/__init__.py`, `backend/app/repositories/base.py`, `backend/app/repositories/cliente_repository.py`, `backend/app/services/cliente_service.py`.

1. `base.py`:
   ```python
   class BaseRepository(Generic[ModelT]):
       model: type[ModelT]
       def __init__(self, db: AsyncSession) -> None: ...
       async def get(self, id: uuid.UUID) -> ModelT | None
       async def list(self, *, filters: Sequence[ColumnElement[bool]] = (), order_by=None, skip: int = 0, limit: int = DEFAULT_PAGE_LIMIT) -> tuple[Sequence[ModelT], int]  # (items, total)
       async def add(self, obj: ModelT) -> ModelT       # add + flush
       async def delete(self, obj: ModelT) -> None
   ```
   `total` se calcula con `select(func.count()).select_from(subquery_filtrada)`. El repositorio **no hace commit**: el commit es del servicio.
2. `cliente_repository.py`: `ClienteRepository(BaseRepository[Cliente])` con `get_by_identificacion(identificacion)` y `search(q, skip, limit)` (ilike sobre `nombres` e `identificacion`, orden `created_at desc`).
3. `cliente_service.py`: `ClienteService(db)` con `registrar`, `listar`, `obtener`, `actualizar`, `eliminar` y `regenerar_otp`. Mueve aquí la lógica de `endpoints/clientes.py` (generación de OTP incluida). Los errores de dominio se expresan con excepciones nuevas en `core/exceptions.py`: `RecursoNoEncontradoException`, `IdentificacionDuplicadaException` y `ConflictoDominioException`. Regístralas en `core/handlers.py` (404, 409 y 409).
4. Refactoriza `endpoints/clientes.py` para que solo valide la entrada, llame al servicio y programe el `BackgroundTasks` del email. **El comportamiento externo no cambia en este commit.** Todas las pruebas existentes deben seguir verdes.

**Commit:** `refactor(clientes): introducir capa base de repositorios y servicio de clientes`

### T3.2 CRUD completo con cédula o RUC única (SGD-59)

**Archivos:** `backend/app/schemas/cliente.py`, `backend/app/services/cliente_service.py`, `backend/app/api/v1/endpoints/clientes.py`, `lib/core/utils/ecuadorian_id_validator.dart`, `backend/tests/unit/test_validation/test_ecuadorian_id.py`, `test/validation_test.dart`.

1. **Validador de RUC** en `schemas/cliente.py` (no modifiques `validar_cedula_ecuatoriana`; agrega funciones nuevas):
   - `validar_ruc_ecuatoriano(ruc: str) -> bool`, con 13 dígitos y provincia válida (01–24 o 30):
     - **Persona natural** (tercer dígito 0–5): los primeros 10 son una cédula válida y los últimos 3 son `>= "001"`.
     - **Sociedad pública** (tercer dígito 6): coeficientes `[3,2,7,6,5,4,3,2]` sobre los dígitos 1–8; `r = suma % 11`; verificador = `0 if r == 0 else 11 - r` y debe ser igual al dígito 9; los últimos 4 son `>= "0001"`.
     - **Sociedad privada o extranjero** (tercer dígito 9): coeficientes `[4,3,2,7,6,5,4,3,2]` sobre los dígitos 1–9; verificador = `0 if r == 0 else 11 - r` y debe ser igual al dígito 10; los últimos 3 son `>= "001"`.
     - Si el verificador calculado es 10 → inválido.
   - `validar_identificacion(valor) -> bool`: 10 dígitos → cédula; 13 dígitos → RUC; cualquier otra longitud → `False`.
   - `ClienteCreate.identificacion` usa `validar_identificacion`, con el mensaje "Identificación inválida: debe ser una cédula (10 dígitos) o un RUC (13 dígitos) ecuatoriano válido." La columna ya es `String(13)`, así que no hace falta migración.
   - Replica el mismo algoritmo en Dart (`ecuadorian_id_validator.dart`) con `isValidRuc` e `isValidIdentificacion`.
   - Pruebas: al menos 2 RUC válidos por tipo y casos inválidos (verificador, sufijo `000`, longitud 11 o 12, tercer dígito 7 u 8). Calcula los RUC válidos de prueba **con el propio algoritmo** dentro de un helper de la prueba; no inventes números a mano.
2. **Unicidad:** si la identificación ya existe → `IdentificacionDuplicadaException` → **409** con el mensaje genérico "Ya existe un cliente con esa identificación." (sin repetir el número, para no filtrar PII en las respuestas). Además, captura `IntegrityError` en el commit para cubrir la condición de carrera y convertirlo en la misma excepción.
3. **Nuevos endpoints** (solo `ADMIN` y `AGENTE`):
   - `PATCH /clientes/{cliente_id}` con `ClienteUpdate(StrictBaseSchema)`: `nombres`, `email` y `telefono` opcionales. **La identificación no se edita.** Si cambia el email y el cliente tiene `usuario_id`, no se toca el email de `usuarios` (documéntalo en el docstring).
   - `DELETE /clientes/{cliente_id}` → 204, solo `ADMIN`. Si el cliente tiene pólizas → `ConflictoDominioException` 409 "No se puede eliminar un cliente con pólizas registradas."
4. Actualiza las pruebas existentes que esperaban 400 por duplicado.
5. Regenera `openapi.json`.

**Commits:**
- `feat(clientes): aceptar ruc ecuatoriano ademas de cedula en la identificacion`
- `feat(clientes): agregar actualizacion y eliminacion de clientes con unicidad 409`

### T3.3 Listado paginado con total (SGD-61, backend)

1. En `schemas/base.py`, agrega `class PaginatedResponse(BaseModel, Generic[T]): items: list[T]; total: int; skip: int; limit: int`.
2. `GET /clientes` devuelve `PaginatedResponse[ClienteResponse]`, con `q` (mínimo 1 carácter después de `strip`), `skip` y `limit` (usa `DEFAULT_PAGE_LIMIT`/`MAX_PAGE_LIMIT` de `core/constants.py`). **No incluyas `codigo_vinculacion` en el listado** (debe ser `None`).
3. Actualiza `ClientsRepository.getClients` en Dart para que devuelva `PaginatedClients {items, total, skip, limit}` con parámetros `q`, `skip` y `limit` (codifica los query params con `Uri`). Revisa los otros consumidores de `getClients` con `grep -rn "getClients" lib test` y ajústalos (por ejemplo, `policy_form_dialog`).
4. Actualiza `test/repositories/clients_repository_test.dart` y `test_client_generation_drift.py` si hace falta. Regenera `openapi.json`.

**Commit:** `feat(clientes): paginar listado de clientes con total y busqueda en servidor`

### T3.4 UI: listado paginado con búsqueda en servidor, alta y edición (SGD-60, 61)

**Archivos:** `clients_tab_view.dart`, `clients_data_table.dart`, `client_form_dialog.dart`, `clients_repository.dart`, `client_model.dart`.

1. `ClientsTabView`: elimina `_filteredClients()`. Cada cambio en el buscador dispara `_loadClients()` con un **debounce de 400 ms** (`Timer`, cancelado en `dispose`) y `skip = 0`. Guarda `_total`, `_skip` y `_limit = 20`. La tabla (`SigadDataTable` de T2.3) muestra la paginación.
2. `ClientFormDialog`: acepta `ClientModel? initial`. En modo edición, la identificación es de solo lectura y al guardar se llama a `updateClient`. El validador de identificación usa `isValidIdentificacion` y el label pasa a "Cédula o RUC". Basa el diálogo en `SigadFormDialog` para que los errores del backend (409, por ejemplo) se vean dentro del diálogo.
3. `ClientsRepository`: agrega `updateClient(id, UpdateClientRequest)` y `deleteClient(id)`.
4. `ClientsDataTable`: acciones por fila "Editar", "Eliminar" (solo si `AuthorizationPolicy` permite la capacidad de administrador; si no existe una capacidad adecuada, agrega `AppCapability.deleteClients` asignada solo a admin en `authorization_policy.dart`), "Generar OTP" (ya existe) y "Registrar vehículo" (el callback se conecta en T4.3). Eliminar pide confirmación con `showSigadConfirm(destructive: true)`.

**Commit:** `feat(ui): listado paginado de clientes con busqueda en servidor edicion y eliminacion`

### T3.5 Pruebas backend de unicidad y búsqueda (SGD-62)

Nuevo `backend/tests/integration/test_clientes_api.py`:
- Crear un cliente con cédula → 201; repetir la misma cédula → 409.
- Crear un cliente con RUC natural cuyo prefijo es la cédula de otro cliente → 201 (son identificaciones distintas).
- Dos `POST` concurrentes con la misma identificación (`asyncio.gather`) → exactamente un 201 y un 409.
- La búsqueda por fragmento de nombre (sin distinguir mayúsculas) y por prefijo de identificación devuelve solo las coincidencias; `total` es correcto; la paginación con `skip`/`limit` no repite elementos.
- `PATCH` cambia el nombre; un `PATCH` con el campo `identificacion` → 422 (`extra="forbid"`).
- `DELETE` como `AGENTE` → 403; como `ADMIN`, si el cliente tiene póliza → 409; si no la tiene → 204.
- Un rol `CLIENTE` en `GET /clientes` → 403.

**Commit:** `test(clientes): cubrir unicidad de identificacion busqueda paginacion y crud`

### T3.6 Widget tests de login y registro de cliente (SGD-63)

- `test/features/auth/login_page_test.dart`: render de campos; validación de campos vacíos; al enviar se dispara `LoginSubmitted` con los valores ingresados (usa un `MockAuthBloc` con `mocktail` y `whenListen`, o el patrón que ya usa `auth_activation_test.dart`); un estado de error muestra el mensaje; un estado de bloqueo muestra `LockoutView`.
- `test/features/web_dashboard/client_form_dialog_test.dart`: rechaza una cédula inválida; acepta una cédula válida y un RUC válido; en modo edición la identificación está deshabilitada; un error del `onSubmit` aparece dentro del diálogo.

Reutiliza `test/helpers/test_factories.dart` y `test_fixtures.dart`.

**Commit:** `test(ui): agregar widget tests de login y registro de cliente`

---

## Fase 4 — HU-04: vehículos (SGD-65 a 68)

### T4.1 Motor, chasis y color (SGD-65)

1. **Migración** `backend/alembic/versions/0008_vehiculo_motor_chasis_color.py` (`down_revision` = id de la `0007`; léelo del archivo): agrega `motor String(30)`, `chasis String(30)` y `color String(30)`, todas `nullable=True` (hay datos existentes), y un índice único parcial `ux_vehiculos_chasis` sobre `chasis WHERE chasis IS NOT NULL`. El `downgrade()` elimina el índice y las columnas.
   Si la migración `0002` define un trigger de auditoría sobre `vehiculos` que lista columnas, verifica que siga funcionando con las columnas nuevas.
2. **Modelo** `vehiculo.py`: agrega los tres `Mapped[str | None]`.
3. **Esquemas** `schemas/vehiculo.py`:
   - `VehiculoCreate`: `motor` (obligatorio, regex `^[A-Z0-9-]{5,30}$`, se normaliza a mayúsculas antes de validar), `chasis` (obligatorio, regex `^[A-HJ-NPR-Z0-9]{17}$` (VIN: sin I, O ni Q), se normaliza a mayúsculas) y `color` (obligatorio, 3–30 caracteres, solo letras, espacios y tildes, se guarda con `strip().upper()`).
   - `VehiculoResponse`: agrega `motor`, `chasis` y `color` como `str | None`.
   - Nuevo `VehiculoUpdate` (opcionales: `marca`, `modelo`, `anio`, `motor`, `chasis`, `color`; **la placa no se edita**) y un endpoint `PATCH /vehiculos/{id}` (solo `ADMIN` y `AGENTE`).
4. **Endpoint** `POST /vehiculos`: pasa los campos nuevos. Un chasis duplicado → 409 "Ya existe un vehículo con ese número de chasis." Una placa duplicada pasa de 400 a **409** (ajusta las pruebas).
5. Dart: `vehicle_model.dart` con los campos nullable nuevos; actualiza las factories de prueba.
6. Ejecuta `alembic upgrade head`, luego `alembic downgrade -1` y de nuevo `alembic upgrade head` en local, y deja constancia en el mensaje del commit.
7. Regenera `openapi.json`.

**Commits:**
- `feat(db): agregar motor chasis y color a vehiculos con indice unico de chasis`
- `feat(vehiculos): validar motor chasis y color y permitir actualizacion parcial`

### T4.2 Clasificación de placas y particiones de equivalencia (SGD-67)

1. En `schemas/vehiculo.py`, agrega `class TipoPlacaEnum(str, Enum): PARTICULAR, MOTO, SERVICIO_PUBLICO, GUBERNAMENTAL` y `clasificar_placa(placa: str) -> TipoPlacaEnum | None` (devuelve `None` si la placa es inválida) según **D5**.
2. Agrega `tipo_placa: TipoPlacaEnum` calculado a `VehiculoResponse` con `@computed_field` (no se persiste).
3. Reescribe `backend/tests/unit/test_validation/test_plates.py` organizado por **particiones**, con un `parametrize` por clase válida e inválida:
   - Válidas: particular (`PBA-1234`, `GYE-0987`, `ICA-0001`); moto 2L+4D (`AB-1234`); moto 2L+3D+1L (`AB-123C`); servicio público (`GAA-1234`, `PUB-0001`, `PZA-9999`); gubernamental (`PEA-1234`, `PXA-1234`, `PMA-0001`).
   - Inválidas: las que ya existen en el archivo.
   - Valores frontera: `XXX-0000` y `XXX-9999` (válidos); `AB-000A` (válido); la letra final de moto en minúscula (inválido).
   - Corrige la descripción actual de `PTA-1234`: según D5 es **particular**, no "servicio público".
4. Agrega `isValidPlate` y `classifyPlate` en `lib/core/utils/plate_validator.dart` (si ya existe un validador de formato, reutilízalo) con pruebas espejo en `test/validation_test.dart`.

**Commit:** `feat(vehiculos): clasificar placas ant por tipo y cubrir particiones de equivalencia`

### T4.3 Pantalla de registro de vehículo asociada a un cliente (SGD-66)

1. Nuevo `lib/core/repositories/vehicles_repository.dart`: `createVehicle(CreateVehicleRequest)`, `getVehiclesByClient(clientId)` y `updateVehicle(...)`. Para listar por cliente, agrega en el backend el filtro opcional `cliente_id: uuid.UUID | None` a `GET /vehiculos` (respeta el filtro por dueño para el rol `CLIENTE`) y regenera OpenAPI. Mueve la llamada a vehículos que hoy está en `policies_repository.dart` para que use este repositorio.
2. Nuevo `lib/features/web_dashboard/presentation/dialogs/vehicle_form_dialog.dart` sobre `SigadFormDialog`:
   - Encabezado de solo lectura con el cliente (nombre e identificación).
   - Campos: placa (en mayúsculas automáticamente, validada con `isValidPlate`, con un chip que muestra el `classifyPlate` en vivo), marca, modelo, año (1900 a año actual + 1), motor, chasis (17 caracteres con contador) y color.
   - Un error del backend (409 por placa o chasis) aparece dentro del diálogo.
3. Nuevo `lib/features/web_dashboard/presentation/dialogs/client_vehicles_dialog.dart`: lista los vehículos del cliente (con `SigadDataTable`: placa, tipo, marca/modelo, año, color) y tiene un botón "Registrar vehículo" que abre el formulario y refresca la lista al guardar.
4. Conecta la acción "Registrar vehículo" o "Vehículos" de `ClientsDataTable` (T3.4) para que abra `ClientVehiclesDialog`.
5. Widget test `test/features/web_dashboard/vehicle_form_dialog_test.dart`: rechaza la placa `PBA123`; acepta `PBA-1234` y muestra "Particular"; rechaza un chasis de 16 caracteres; envía el request con el `cliente_id` correcto.

**Commits:**
- `feat(vehiculos): filtrar vehiculos por cliente en el listado`
- `feat(ui): agregar registro y listado de vehiculos por cliente`

### T4.4 404 uniforme para recursos ajenos (SGD-68)

1. En `core/exceptions.py` usa `RecursoNoEncontradoException` (T3.1) con el mensaje único `"Recurso no encontrado."`.
2. Cambia a 404 uniforme (mismo cuerpo, sin revelar si el recurso existe):
   - `POST /vehiculos`: cuando un `CLIENTE` usa un `cliente_id` ajeno (hoy 403) **y** cuando el `cliente_id` no existe (hoy 404 con el ID en el mensaje).
   - `GET /clientes/{id}`: cuando un `CLIENTE` consulta otro cliente (hoy 403).
   - `GET /vehiculos/{id}` y el nuevo `PATCH`: usan el mensaje uniforme.
   - Revisa `polizas.py`, `documentos.py`, `pagos.py` y `asistencias.py` con `grep -n "HTTP_403_FORBIDDEN\|HTTP_404_NOT_FOUND" backend/app/api/v1/endpoints/*.py`. Donde un 403 o 404 dependa de **la propiedad del recurso** (no del rol), reemplázalo por la excepción uniforme. **Los 403 de `check_role` (rol insuficiente) se mantienen.**
3. Nueva prueba `backend/tests/integration/test_recursos_ajenos_404.py`, parametrizada sobre las rutas afectadas. Para cada una verifica que (a) el recurso ajeno y (b) un UUID inexistente devuelven el **mismo** status y el **mismo** cuerpo JSON. Ajusta `test_bola_query_level.py` y `test_idor_documentos.py` si esperaban 403.

**Commit:** `fix(seguridad): responder 404 uniforme ante recursos ajenos o inexistentes`

---

## Fase 5 — HU-05: despliegue y CI (SGD-69, 70, 73 a 76, 80)

### T5.1 Imagen `sigadbackend` (SGD-69)

En `docker-compose.yml`, para los servicios `api` y `worker`, agrega `image: ${SIGAD_IMAGE:-ghcr.io/xavih830/sigadbackend}:${SIGAD_TAG:-latest}` y conserva el bloque `build`. Agrega `SIGAD_IMAGE` y `SIGAD_TAG` comentados en `.env.example`. En el `Dockerfile`, agrega `LABEL org.opencontainers.image.source="https://github.com/Xavih830/SIGAD"` y `org.opencontainers.image.title="sigadbackend"`. (Verifica el nombre real del repositorio con `git remote -v` y usa el owner en minúsculas.)

Verifica: `docker compose config` sin errores y `docker compose build api` con éxito.

**Commit:** `chore(docker): nombrar la imagen del backend como sigadbackend publicable en ghcr`

### T5.2 Caddy con TLS automático (SGD-70)

1. Cambia la cabecera del sitio del `Caddyfile` a `{$SIGAD_DOMAIN:localhost} {`. Con un dominio real, Caddy obtiene el certificado de Let's Encrypt y redirige HTTP→HTTPS de forma automática; con `localhost`, usa su CA interna.
2. Agrega un bloque global al inicio: `{ email {$ACME_EMAIL:admin@localhost} }`.
3. Mantén el acceso de desarrollo por el puerto 8085: agrega un segundo bloque `http://:8085 { ... }` que importe la misma configuración. Para no duplicarla, extrae las cabeceras y los `handle` a un snippet `(sigad_common) { ... }` y usa `import sigad_common` en ambos bloques.
4. En compose, pasa `SIGAD_DOMAIN` y `ACME_EMAIL` al servicio `caddy` (`environment:`), y cambia el mapeo `8085:80` por `8085:8085`.
5. Agrega `SIGAD_DOMAIN` y `ACME_EMAIL` a `.env.example`.
6. **Antes de cambiar nada, lee `test_caddy_headers.py`, `test_health_probes.py` y `test_architecture_config.py`, que parsean el `Caddyfile`, y ajústalos a la nueva estructura.** Valida con `docker run --rm -v "$PWD/Caddyfile:/etc/caddy/Caddyfile" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile`.

**Commit:** `feat(ingress): habilitar tls automatico en caddy por dominio configurable`

### T5.3 GitHub Actions completo (SGD-73, 76)

Reescribe `.github/workflows/ci.yml` con estos **jobs**:

| Job | `needs` | Contenido |
|---|---|---|
| `lint-backend` | — | `pip install ruff` → `ruff check backend` → `ruff format --check backend` (si `format --check` falla en masa, omite este paso y deja un `# TODO` explícito) |
| `backend-test` | `lint-backend` | El actual, sin el step de OpenAPI, con el ciclo de migraciones de T5.6 |
| `export-openapi` | `lint-backend` | Instala dependencias → `python backend/scripts/export_openapi.py` (sin Postgres y sin `.env`, gracias a T5.5) → `git diff --exit-code openapi.json` → `actions/upload-artifact` con `openapi.json` |
| `generate-client` | `export-openapi` | Descarga el artefacto → `PYTHONPATH=. pytest tests/unit/test_quality/test_client_generation_drift.py tests/unit/test_quality/test_openapi_drift.py` (ver D2) |
| `flutter-test` | — | El actual (`flutter analyze`, `flutter test --coverage`) |
| `publish-ghcr` | `backend-test`, `generate-client`, `flutter-test` | Solo `if: github.event_name == 'push' && (github.ref == 'refs/heads/main' \|\| startsWith(github.ref, 'refs/tags/v'))`. `permissions: packages: write, contents: read`. Usa `docker/login-action@v3` (registry `ghcr.io`, `${{ github.actor }}`, `${{ secrets.GITHUB_TOKEN }}`), `docker/metadata-action@v5` (tags: `type=semver,pattern={{version}}`, `type=sha`, `type=raw,value=latest,enable={{is_default_branch}}`) y `docker/build-push-action@v6` con `push: true` |

- Triggers: `push` en `main`, `v2`, `Sprint1` y tags `v*.*.*`; `pull_request` hacia `main` y `v2`.
- Cambia el nombre del job "Backend Verification & 37 Tests Suite" por uno que no fije un número de pruebas.
- **Primero ejecuta `ruff check backend` localmente.** Corrige lo que sea seguro con `ruff check backend --fix` en un **commit separado** (`style(backend): aplicar correcciones automaticas de ruff`). Lo que quede, corrígelo a mano o agrega exclusiones puntuales (`per-file-ignores`) justificadas en `pyproject.toml`.
- No modifiques `build-apk.yml`.

**Commits:**
- `style(backend): aplicar correcciones automaticas de ruff`
- `ci: separar jobs de lint openapi y drift de cliente y publicar imagen en ghcr`

### T5.4 Convenciones del repositorio (SGD-74)

1. `docs/CONTRIBUTING.md`:
   - **Ramas:** `main` (producción, protegida), `v2`/`develop` (integración), `feature/SGD-<n>-<slug>`, `fix/SGD-<n>-<slug>`, `chore/<slug>`, `release/vX.Y.Z`, `hotfix/vX.Y.Z`. Merge a `main` solo por PR con CI en verde y una revisión.
   - **Tags semánticos:** `vMAJOR.MINOR.PATCH`, con criterios de incremento; el tag dispara `publish-ghcr`.
   - **Commits:** enlaza a `README.md` §1 (no lo dupliques) y agrega que el ID de Jira va en el cuerpo: `Refs: SGD-59`.
   - **Definition of Ready:** la historia tiene formato "Como… quiero… para…", criterios de aceptación verificables, estimación en story points, dependencias identificadas, diseño o prototipo enlazado si tiene UI, datos de prueba disponibles y cabe en el sprint.
   - **Definition of Done:** el código pasó la revisión del PR; ruff, pytest, `flutter analyze` y `flutter test` están en verde; `openapi.json` está sin drift; hay pruebas de los criterios de aceptación; `docs/UpdatesSprint1.md` está actualizado; desplegado en staging o validado con `docker compose up`.
2. `.github/pull_request_template.md` con estas secciones: Resumen, Issue Jira (`SGD-`), Tipo de cambio (checkboxes), Cómo se probó, Checklist DoD, Capturas (si hay UI) y Riesgos o rollback.
3. Enlaza `docs/CONTRIBUTING.md` desde el README.

**Commit:** `docs: definir convencion de ramas tags semanticos plantilla de pr y definition of ready`

### T5.5 `export_openapi.py` con variables ficticias (SGD-75)

1. Lee `backend/app/core/config.py` y lista **todos** los campos sin valor por defecto (por ejemplo `DATABASE_URL`, `JWT_SECRET_KEY`, `OTP_SECRET_KEY_*`, `SMTP_*`, `UPLOAD_DIR`).
2. En `export_openapi.py`, **antes** de `from app.main import app`, define `_VARIABLES_FICTICIAS: dict[str, str]` con valores obviamente falsos (`postgresql+asyncpg://openapi:openapi@invalid.local:5432/openapi`, `"openapi-export-dummy-secret-0000000000"`, etc.) y aplícalos con `os.environ.setdefault`. Fuerza `ENVIRONMENT="development"` para que FastAPI genere `openapi_url`. Mueve el import de `app.main` dentro de `export_schema()` para que también ocurra con los sockets bloqueados. Asegura que `backend_dir` esté en `sys.path`, para que el script funcione desde la raíz del repo.
3. Si `Settings` lee `.env` desde el directorio de trabajo, el script debe funcionar sin ese archivo: pruébalo con `cd /tmp && python <ruta>/backend/scripts/export_openapi.py`.
4. En `test_openapi_export.py`, agrega `test_export_sin_env_usa_variables_ficticias`: un subprocess con `env` limpio (solo `PATH` y `PYTHONPATH`) y `cwd=tmp_path` debe terminar con código 0 y generar un JSON con la clave `paths`.

**Commit:** `fix(openapi): exportar contrato con variables ficticias sin depender de env ni red`

### T5.6 Verificación de upgrade/downgrade de migraciones (SGD-80)

1. En el job `backend-test` de CI, después de `alembic upgrade head`, agrega un step: `alembic downgrade base && alembic upgrade head`.
2. Crea `backend/tests/integration/test_migraciones_ciclo.py`, marcado con `@pytest.mark.migraciones` y **excluido por defecto** (registra el marker en `pyproject.toml` y agrega `-m "not migraciones"` a `addopts`, o protégelo con `skipif` usando una variable de entorno `RUN_MIGRATION_CYCLE=1`). Debe ejecutar con `subprocess` `alembic downgrade base`, `alembic upgrade head`, `alembic downgrade -1` y `alembic upgrade head` contra la BD de pruebas, y comprobar que `rol_enum` existe después del upgrade y no existe después del `downgrade base`.
3. Si `downgrade base` falla en alguna migración (por ejemplo, tipos enum que no se eliminan en `0002`–`0007`), corrige el `downgrade()` de esa migración en un commit `fix(db): ...`.

**Commit:** `test(db): verificar ciclo completo de upgrade y downgrade de migraciones`

---

## Fase 6 — HU-06: documentación de campos de póliza (SGD-82)

### T6.1 Diccionario de campos de póliza

Crea `docs/campos-poliza.md` con una tabla generada **leyendo** `backend/app/models/poliza.py`, `cobertura.py`, `deducible.py`, `vehiculo.py`, `inspeccion.py` y `esquema_poliza.py`. Columnas de la tabla: campo, tabla, tipo, obligatorio, origen (fijo o esquema dinámico), ejemplo y "Validado por PO (sí/no)", con esta última columna **vacía**. Agrega una sección "Pendiente de validar con la Product Owner" que liste los campos sin equivalente claro. No inventes campos de negocio que no estén en el código.

**Commit:** `docs(polizas): documentar diccionario de campos de poliza para validacion con la po`

👤 *La revisión con la PO de las pólizas de ejemplo es humana; el agente solo prepara el documento.*

---

## 4. Verificación final del sprint

Cuando termines todas las fases:

1. `cd backend && ruff check . && PYTHONPATH=. pytest tests/ -q` → todo en verde.
2. `python backend/scripts/export_openapi.py && git diff --exit-code openapi.json` → sin cambios.
3. `flutter analyze && flutter test` → todo en verde.
4. `docker compose up --build -d` → los 5 servicios en estado `healthy` (`docker compose ps`); `curl -k https://localhost/health` devuelve `{"status":"ok","database":"connected"}`.
5. Flujo manual web: login → Clientes → crear un cliente con RUC → buscarlo → editarlo → registrar un vehículo con motor, chasis y color → esperar a que expire el access token (o borrarlo del vault) y confirmar que el refresh es transparente → revocar la sesión y confirmar la redirección a login con el mensaje.
6. Agrega la entrada final en `docs/UpdatesSprint1.md` con la lista de SGD cerradas y las que quedan con 👤.

## 5. Pendiente de decisión humana

- **D1:** confirmar que es aceptable no usar FastAPI-Users.
- **D5:** confirmar con la PO la regla de clasificación de placas por la segunda letra.
- Verificación manual en Chrome, Firefox y Safari (T2.4).
- Validación de los campos de póliza con la PO (T6.1).
- Crear en GitHub la protección de la rama `main` y comprobar que `GITHUB_TOKEN` tiene permiso `packages: write` en el repositorio.
