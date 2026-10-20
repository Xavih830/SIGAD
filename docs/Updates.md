# Registro de Actualizaciones - SIGAD

## [1.0.0] - 2026-06-24
### Inicialización y Desarrollo Completo de la Fase 1
- **Inicialización del Proyecto:** Creación de la estructura del proyecto Flutter (`sigad`) y configuración de dependencias (`flutter_bloc`, `hive_flutter`, `flutter_local_notifications`, `url_launcher`, `crypto`, `intl`).
- **Arquitectura Limpia (Clean Architecture):** Implementación de la separación de responsabilidades en capas (`core`, `features/auth`, `features/mobile_client`, `features/web_dashboard`).
- **Persistencia Local (Hive):** Diseño del `HiveHelper` y carga de base de datos local con datos predefinidos para Clientes, Pólizas Vehiculares (livianas/pesadas), Talleres Autorizados y Números de Asistencia.
- **Módulo de Autenticación:** Lógica de login en `AuthBloc` utilizando hash SHA-256 para contraseñas, guardado de sesión para inicio automático y mecanismo de bloqueo por 5 minutos tras 3 intentos fallidos consecutivos (con contador visible).
- **Plataforma Web Administrativa:**
  - Gestión de usuarios del sistema (Admin).
  - Gestión de clientes con validación de cédula ecuatoriana de 10 dígitos.
  - Gestión de pólizas vehiculares (creación de pólizas livianas y pesadas con validación de placa única, duplicación de pólizas como borrador, soft-delete e historial de cambios).
  - Lector Documental OCR Simulador (extracción de campos con indicador de nivel de confianza y panel de revisión).
  - Reportes de portafolio y bitácora de auditoría de cambios con soporte de exportación a PDF por impresión de navegador.
  - Selector de alertas de vencimiento en 30, 60 y 90 días.
- **Aplicación Móvil para Clientes:**
  - Splash Screen de 2 segundos con logotipo corporativo y animación.
  - Panel principal con tarjetas de pólizas y alertas visuales para vencimientos menores a 30 días.
  - Detalle de póliza de solo lectura y botón para reportar errores.
  - Módulo de Asistencia y Talleres Autorizados con acciones de llamada telefónica integradas (`tel:`).
- **Notificaciones Locales:** Motor de programación de notificaciones de vencimiento a los 30d, 15d, 7d y 0d antes de expirar, y alerta de bienvenida tras primer ingreso.
- **Soporte Multiplataforma Completo:** Migración del disparador de impresión de navegador a un ayudante condicional `print_helper.dart` para aislar `dart:html` y asegurar que la aplicación compile sin fallos tanto para entorno Web como para compilación de APK en Android.
- **Configuración de Control de Versiones:** Adición de la carpeta `documentos/` al archivo `.gitignore` para omitir especificaciones locales.

## [1.0.1] - 2026-06-24
### Corrección de Compilación Móvil y Optimización de Gitignore
- **Resolución de Errores de Notificaciones:** Modificación de las llamadas a métodos del plugin `FlutterLocalNotificationsPlugin` (`initialize`, `show`, `cancel`, `zonedSchedule`) en `notifications_manager_mobile.dart` para adaptarlas al uso de parámetros con nombre (named parameters) de acuerdo con la API de la versión `22.0.1` instalada.
- **Soporte de Java 8 (Desugaring):** Configuración de desugaring de APIs de Java 8 (`isCoreLibraryDesugaringEnabled = true` y dependencia `desugar_jdk_libs:2.1.4`) en `android/app/build.gradle.kts` para permitir la compilación exitosa de las librerías nativas en la release APK.
- **Remoción de Parámetros Obsoletos:** Eliminación de `uiLocalNotificationDateInterpretation` del método `zonedSchedule`, el cual ya no es parte de la firma del método en la versión actual del plugin.
- **Configuración de Seguridad en Gitignore:** Inclusión de archivos de metadatos y configuraciones del IDE de desarrollo local (`.idea/`, `.metadata`, `*.iml`) al archivo `.gitignore` para evitar la subida innecesaria de archivos de configuración local al control de versiones.

## [1.0.2] - 2026-06-24
### Corrección de Experiencia de Usuario y Consistencia de Marca
- **Navegación Inmediata de Sesión:** Implementación de redirección automática e inmediata en `LoginPage`, `MobileDashboardPage` y `WebDashboardPage` a través de `BlocListener` ante cambios en el estado de autenticación de `AuthBloc`, evitando la necesidad de reiniciar o deslizar la aplicación para aplicar los cambios de sesión.
- **Optimización de Logotipo (SigadLogo):** Rediseño del widget de logotipo corporativo para separar la representation visual (icono con escudo y automóvil) del texto "SIGAD", evitando solapamientos y recortes de letras. Soporta colores de texto dinámicos según el fondo (Login/Splash).
- **Generación de Iconos de Lanzador (Launcher Icons):** Implementación y ejecución de un script de generación programática en Python para rasterizar y guardar el logotipo en todos los mipmaps de Android y el conjunto de imágenes de iOS.
- **Consistencia del Nombre del Sistema (SIGAD):** Corrección del nombre en el atributo `android:label` en `AndroidManifest.xml` y las claves `CFBundleDisplayName`/`CFBundleName` en `Info.plist` para asegurar que el sistema se identifique unificadamente como "SIGAD" en mayúsculas en la pantalla de inicio y el administrador de tareas del celular.

## [1.0.3] - 2026-07-05
### Soporte Multicategoría de Pólizas y Diseño Adaptativo Web
- **Persistencia y Semillas de Datos:** Actualización de `hive_helper.dart` con la inserción de pólizas de prueba de Salud, Vida e Incendio para Carlos Pérez, María León y Roberto Vega respectivamente.
- **Formularios Condicionales de Pólizas:** Refactorización de la creación y edición de pólizas en `web_dashboard_page.dart` para ocultar y omitir la validación de campos vehiculares (placa, marca, modelo, año, color, tonelaje) al gestionar pólizas de Seguro de Salud, Vida, Incendios u Otros.
- **Validación Documental OCR Adaptada:** Actualización de la validación del parser OCR para ignorar los requerimientos de datos vehiculares en categorías no vehiculares, previniendo errores durante su almacenamiento en local.
- **Estadísticas de Distribución Ampliadas:** Integración de cálculos y visualización en el gráfico del reporte web para los seis tipos de póliza con sus porcentajes y cantidades correspondientes.
- **Interfaz Móvil Adaptativa y Dinámica:** 
  - Rediseño de las tarjetas del listado en `mobile_dashboard_page.dart` para aplicar tags de color y etiquetas personalizadas para Salud (verde), Vida (teal), Incendios (rojo), Otros (púrpura) y ocultar la placa.
  - Actualización de `policy_detail_page.dart` para ocultar la sección "Datos del Vehículo" si la póliza seleccionada es de tipo no vehicular.
  - Corrección de banner del dashboard móvil para reflejar pólizas activas en general.

## [1.0.4] - 2026-07-06
### Reversión a Pólizas Vehiculares y Pulido de UI Web y Móvil
- **Reversión a Pólizas Vehiculares Exclusivas:** Reversión completa de la persistencia de datos (semilla), formularios de creación/edición, lector OCR, reportes y dashboards tanto en web como en móvil para dar soporte únicamente a pólizas vehiculares (`liviano` y `pesado`).
- **Limpieza de UI y Exclusión de Jerga:** Eliminación de descripciones de persistencia técnica interna como "(Persistencia Local)", "Local Path" y "OCR local" en la interfaz administrativa para ofrecer un entorno de usuario más profesional.
- **Configuración de Favicon y Título de la Pestaña:** Adición y configuración de favicon corporativo (`web/favicon.png`) basado en el escudo oficial y actualización de la etiqueta de título `<title>SIGAD</title>` en mayúsculas en `web/index.html`.
- **Corrección de Errores Visuales de Desbordamiento (Overflow):** Envoltura de las DataTables (pólizas, clientes y usuarios) en `SingleChildScrollView` horizontal para resoluciones móviles/de ventana reducidas y ajuste de coordenadas del `_LogoPainter` para añadir un margen de seguridad anti-aliasing.

## [2.0.0] - 2026-10-20
### Sincronización de Ramas, Resolución de Conflictos y Documentación de v2
- **Fusión de main hacia v2:** Integración de la versión vehicular limpia y resolución de conflictos en `sigad_logo.dart` (márgenes seguros de canvas), `test/auth_bloc_test.dart` (compatibilidad con mocks), `policy_detail_page.dart`, `mobile_dashboard_page.dart` y `web_dashboard_page.dart`.
- **Certificación de Calidad:** Ejecución exitosa de la suite completa de 152 pruebas unitarias y de widgets (`flutter test`).
- **Documentación de Nuevas Capacidades:** Creación de `docs/funcionalidades_nuevas_v2.md` con el detalle de las nuevas funcionalidades para clientes (activación con OTP, cronograma de cuotas HU-20) y administradores (esquemas OCR HU-06/07, tablas paginadas, formularios dinámicos).
- **Diagnóstico de Ejecución Web:** Análisis del requisito de configuración fail-fast de variables de entorno (`.env.client` y `API_BASE_URL`) para la correcta inicialización de la UI en Chrome.

## [2.0.1] - 2026-10-20
### Diagnóstico de Conectividad con el Backend y Retroalimentación Visual en UI
- **Resolución de Variables de Entorno en Docker:** Aprovisionamiento del archivo canónico `.env` en la raíz del repositorio a partir de `.env.example`, resolviendo la ausencia de la variable requerida `UPLOAD_DIR=uploads` que bloqueaba `docker compose up`.
- **Configuración de Cliente Frontend:** Creación de `.env.client` con `API_BASE_URL=http://localhost:8000` para la comunicación del cliente Flutter con el backend FastAPI y Caddy.
- **Componente Visual de Error de Conexión (`BackendErrorBanner`):**
  - Implementación del widget interactivo `BackendErrorBanner` (`lib/core/widgets/backend_error_banner.dart`) que detecta fallos de conectividad, servidor no iniciado o parámetros faltantes.
  - Ofrece instrucciones visuales claras para el usuario y desarrollador: levantar `docker compose up` y ejecutar Flutter Web con el puerto CORS autorizado (`--web-port=8085`).
  - Incluye botón reactivo "Comprobar backend" para enviar una solicitud de verificación a `/health` y notificar inmediatamente si el backend ya está disponible.
- **Integración en Pantallas de Acceso:** Adición del banner en `LoginPage` y `AccountActivationPage`, junto a un aviso proactivo si la variable `API_BASE_URL` no fue inyectada.
- **Suite de Pruebas:** Implementación de `test/widgets/backend_error_banner_test.dart` y certificación exitosa de todas las 153 pruebas de Flutter (`flutter test`).

