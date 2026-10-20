# Nuevas Funcionalidades para el Usuario en la Rama v2

Este documento detalla todas las **funcionalidades nuevas orientadas al usuario** (tanto clientes móviles como administradores web) implementadas en la rama `v2` en comparación con la versión inicial del proyecto.

---

## 1. Módulo de Autenticación y Activación de Cuenta (Clientes)

### 1.1 Activación Móvil con Código OTP (HU-01 / HU-13)
* **Enlace de activación en Login:** En la pantalla de inicio de sesión de la app móvil se añadió el enlace interactivo: *"¿Primera vez aquí? Activa tu cuenta"*.
* **Pantalla de Activación (`AccountActivationPage`):**
  * Permite al nuevo asegurado ingresar su Cédula/RUC y registrar su contraseña.
  * Valida un **código OTP de seguridad** (enviado por WhatsApp / SMS) para certificar la identidad del cliente antes de permitir el acceso.
* **Simulador Web de Envío OTP por WhatsApp (`OtpWhatsappDialog`):**
  * Permite a los administradores generar y visualizar el código de vinculación para asistir a clientes que requieran soporte en la activación.

### 1.2 Temporizador Reactivo de Bloqueo contra Fuerza Bruta (`LockoutView`)
* En caso de múltiples intentos fallidos de inicio de sesión, el sistema muestra un temporizador visual de cuenta regresiva en tiempo real.
* El botón de inicio de sesión se deshabilita de manera reactiva y no permite reintentos hasta que expire exactamente el tiempo de penalización.

---

## 2. Gestión Financiera y Cronograma de Cuotas (HU-20)

### 2.1 Desglose de Cuotas Mensuales en App Móvil (`PolicyInstallmentsSectionCard`)
* Al acceder al detalle de cualquier póliza en la aplicación móvil, ahora se incluye la tarjeta interactiva de **"Cronograma de Pagos"**:
  * **Lista detallada de cuotas:** Muestra el número de cuota, la fecha exacta de vencimiento y el monto a pagar en dólares (USD).
  * **Semáforo de estado de cada cuota:**
    * 🟢 **Pagada:** Cuota cancelada al día.
    * ⚪ **Pendiente:** Cuota próxima dentro de plazo.
    * 🔴 **Vencida / En Mora:** Cuota que superó la fecha límite sin pago.
* **Manejo de resiliencia y reintentos:** Si ocurre un fallo de red o el servidor responde con error, se muestra un mensaje explicativo y un botón de **"Reintentar"** que recarga las cuotas sin cerrar la pantalla.

### 2.2 Estado Financiero Consolidado en Tiempo Real
* En la cabecera económica de la póliza se calcula automáticamente el estado consolidado del asegurado:
  * *"Al día"* (color verde).
  * *"Con cuotas pendientes"* (color ámbar).
  * *"En mora"* (color rojo alertando cuotas vencidas).

### 2.3 Generación Automática de Cuotas al Emitir Pólizas
* Al registrar una póliza desde el panel web administrativo, el sistema calcula y genera automáticamente el cronograma de cuotas mensuales dividido a lo largo del periodo de vigencia.

---

## 3. Lector Documental OCR y Esquemas Dinámicos (HU-06 / HU-07)

### 3.1 Pestaña de Gestión de Esquemas OCR (`OcrSchemasTabView`)
* **Eliminación de lógica rígida en código:** Los administradores ahora pueden crear, consultar y editar esquemas dinámicos para distintas aseguradoras o formatos de contrato.
* **Prueba de esquemas en vivo (`SchemaTestDialog`):** Permite ingresar un texto de prueba y comprobar en tiempo real cómo el extractor procesa las expresiones regulares y reglas de extracción.
* **Barra de Re-extracción masiva (`OcrSchemaReextractionBar`):** Facilita volver a procesar documentos digitalizados cuando se actualizan las reglas de un esquema.

### 3.2 Formulario Interactivo de Revisión y Corrección OCR
* **Visor del texto original (`OcrRawTextPreview`):** Permite inspeccionar el texto extraído tal como fue digitalizado por el motor OCR.
* **Edición en línea de campos extraídos (`OcrEditableFieldsList`):**
  * Presenta cada campo detectado junto con su nivel de confianza (Verde: Alta, Amarillo: Advertencia, Rojo: Baja o Campo Vacío).
  * El operador puede corregir cualquier dato impreciso directamente en la interfaz antes de aprobar la póliza.
* **Descarga de Documento Digitalizado:** Botón directo para descargar en el navegador el archivo PDF o imagen original cargado en el sistema.

---

## 4. Formularios Dinámicos de Pólizas (`DynamicPolicyForm`)

* **Campos tipados adaptables:** El formulario de creación y edición de pólizas ahora interpreta los tipos de datos requeridos por cada póliza (texto, fecha, valor monetario, listas de selección).
* **Secciones organizadas por pestañas y bloques:**
  * Selector de Esquema y Categoría de Póliza.
  * Datos Básicos de Contrato.
  * Datos Vehiculares (Marca, Modelo, Año, Placa, Color, Tonelaje).
  * Coberturas y Deducibles parametrizados.

---

## 5. Optimizaciones en la Experiencia de Usuario Web

### 5.1 Navegación Basada en Roles (`DashboardSidebar` y `DashboardTabRegistry`)
* Menú lateral modular que solo presenta las opciones para las cuales el usuario autenticado tiene permisos:
  * Administrador de Aseguradora / Corredor: Acceso total (Pólizas, Clientes, OCR, Esquemas, Reportes, Usuarios, Asistencias, Talleres).
  * Agente o Consulta: Vista limitada a sus áreas autorizadas.

### 5.2 Paginación y Rendimiento en Tablas de Datos
* **`PoliciesDataTable` y `ClientsDataTable`:**
  * Control de paginación que permite elegir el número de registros por página (10, 20, 50).
  * Botones de navegación de páginas (anterior / siguiente) y contador de registros totales.
  * Desplazamiento horizontal fluido (`SingleChildScrollView`) que garantiza que las tablas no se corten en pantallas pequeñas o laptops de 13 pulgadas.

### 5.3 Gestión Integral de Talleres y Asistencias
* Módulo con diálogos dedicados para registrar y actualizar la información de talleres mecánicos asociados (`WorkshopFormDialog`) y números telefónicos de auxilio vial (`AssistanceFormDialog`).

---

## 6. Nueva Arquitectura de la App Móvil para Clientes

* **Barra de navegación inferior con 4 módulos dedicados:**
  1. **Mis Pólizas:** Vista de tarjetas con contador de pólizas vehiculares activas, días restantes para vencimiento y acceso al detalle.
  2. **Asistencias:** Directorio de teléfonos de emergencia con botón de llamada rápida de un solo toque (`tel:`).
  3. **Talleres:** Lista de talleres autorizados con dirección física y contacto telefónico.
  4. **Contacto:** Información institucional del corredor RJ Seguros, horarios de atención al cliente y opción de cierre de sesión seguro.
