# Diccionario de Campos de Póliza de Seguro Automotor (SIGAD)

Este documento detalla el diccionario unificado de datos para pólizas, vehículos, coberturas, deducibles, inspecciones y esquemas dinámicos, extraído de los modelos formales del sistema para su auditoría y homologación con la Product Owner (PO).

---

## 1. Tabla de Campos del Modelo de Datos

| Campo | Tabla | Tipo | Obligatorio | Origen | Ejemplo | Validado por PO (sí/no) |
|---|---|---|---|---|---|---|
| `id` | `polizas` | UUID | Sí | Fijo | `f47ac10b-58cc-4372-a567-0e02b2c3d479` | |
| `numero_poliza` | `polizas` | String(50) | Sí | Fijo | `POL-2026-001234` | |
| `cliente_id` | `polizas` | UUID | Sí | Fijo | `3fa85f64-5717-4562-b3fc-2c963f66afa6` | |
| `vehiculo_id` | `polizas` | UUID | Sí | Fijo | `c9a85f64-5717-4562-b3fc-2c963f66afa6` | |
| `inspeccion_id` | `polizas` | UUID | No | Fijo | `d9a85f64-5717-4562-b3fc-2c963f66afa6` | |
| `fecha_inicio` | `polizas` | Date | Sí | Fijo | `2026-01-01` | |
| `fecha_fin` | `polizas` | Date | Sí | Fijo | `2027-01-01` | |
| `estado` | `polizas` | Enum (`activa`, `vencida`, `pendiente`, `cancelada`) | Sí | Fijo | `activa` | |
| `valor_asegurado` | `polizas` | Numeric(12, 2) | Sí | Fijo | `25000.00` | |
| `prima_mensual` | `polizas` | Numeric(10, 2) | Sí | Fijo | `85.50` | |
| `kilometraje_emision` | `polizas` | Integer | Sí | Fijo | `35000` | |
| `esquema_id` | `polizas` | UUID | No | Fijo | `e9a85f64-5717-4562-b3fc-2c963f66afa6` | |
| `campos_adicionales` | `polizas` | JSONB | No | Dinámico | `{"radio_operacion_km": 150.0, "dispositivo_gps": true}` | |
| `created_at` | `polizas` | DateTime (UTC) | Sí | Fijo | `2026-01-01T10:00:00Z` | |
| `updated_at` | `polizas` | DateTime (UTC) | Sí | Fijo | `2026-01-01T10:00:00Z` | |
| `id` | `vehiculos` | UUID | Sí | Fijo | `c9a85f64-5717-4562-b3fc-2c963f66afa6` | |
| `placa` | `vehiculos` | String(10) | Sí | Fijo | `PBA-1234` | |
| `marca` | `vehiculos` | String(100) | Sí | Fijo | `Chevrolet` | |
| `modelo` | `vehiculos` | String(100) | Sí | Fijo | `D-Max` | |
| `anio` | `vehiculos` | Integer | Sí | Fijo | `2023` | |
| `motor` | `vehiculos` | String(30) | No en BD / Sí en creación | Fijo | `4JJ1-123456` | |
| `chasis` | `vehiculos` | String(30) | No en BD / Sí en creación (VIN) | Fijo | `9BF1234567890ABCD` | |
| `color` | `vehiculos` | String(30) | No en BD / Sí en creación | Fijo | `BLANCO` | |
| `cliente_id` | `vehiculos` | UUID | Sí | Fijo | `3fa85f64-5717-4562-b3fc-2c963f66afa6` | |
| `created_at` | `vehiculos` | DateTime (UTC) | Sí | Fijo | `2026-01-01T10:00:00Z` | |
| `updated_at` | `vehiculos` | DateTime (UTC) | Sí | Fijo | `2026-01-01T10:00:00Z` | |
| `id` | `coberturas` | UUID | Sí | Fijo | `2fa85f64-5717-4562-b3fc-2c963f66afa6` | |
| `poliza_id` | `coberturas` | UUID | Sí | Fijo | `f47ac10b-58cc-4372-a567-0e02b2c3d479` | |
| `nombre` | `coberturas` | String(255) | Sí | Fijo | `Responsabilidad Civil` | |
| `monto` | `coberturas` | Numeric(12, 2) | Sí | Fijo | `50000.00` | |
| `created_at` | `coberturas` | DateTime (UTC) | Sí | Fijo | `2026-01-01T10:00:00Z` | |
| `id` | `deducibles` | UUID | Sí | Fijo | `1fa85f64-5717-4562-b3fc-2c963f66afa6` | |
| `poliza_id` | `deducibles` | UUID | Sí | Fijo | `f47ac10b-58cc-4372-a567-0e02b2c3d479` | |
| `tipo_siniestro` | `deducibles` | Enum (`general`, `robo`, `choque`, `perdida_total`) | Sí | Fijo | `choque` | |
| `porcentaje_valor` | `deducibles` | Numeric(5, 2) | Sí | Fijo | `10.00` | |
| `monto_minimo_usd` | `deducibles` | Numeric(10, 2) | Sí | Fijo | `250.00` | |
| `created_at` | `deducibles` | DateTime (UTC) | Sí | Fijo | `2026-01-01T10:00:00Z` | |
| `id` | `inspecciones` | UUID | Sí | Fijo | `d9a85f64-5717-4562-b3fc-2c963f66afa6` | |
| `vehiculo_id` | `inspecciones` | UUID | Sí | Fijo | `c9a85f64-5717-4562-b3fc-2c963f66afa6` | |
| `fecha` | `inspecciones` | DateTime (UTC) | Sí | Fijo | `2026-01-01T09:00:00Z` | |
| `kilometraje` | `inspecciones` | Integer | Sí | Fijo | `35000` | |
| `observaciones` | `inspecciones` | Text | No | Fijo | `Sin novedades estéticas ni mecánicas.` | |
| `created_at` | `inspecciones` | DateTime (UTC) | Sí | Fijo | `2026-01-01T09:00:00Z` | |
| `id` | `esquemas_poliza` | UUID | Sí | Fijo | `e9a85f64-5717-4562-b3fc-2c963f66afa6` | |
| `codigo` | `esquemas_poliza` | String(80) | Sí | Fijo | `FLOTA_PESADA_2026` | |
| `nombre` | `esquemas_poliza` | String(100) | Sí | Fijo | `Esquema de Flota Pesada y Transporte` | |
| `descripcion` | `esquemas_poliza` | Text | No | Fijo | `Configuración de campos dinámicos para camiones y buses.` | |
| `version` | `esquemas_poliza` | Integer | Sí | Fijo | `1` | |
| `es_activo` | `esquemas_poliza` | Boolean | Sí | Fijo | `true` | |
| `campos` | `esquemas_poliza` | JSONB | Sí | Dinámico | `[{"nombre": "radio_operacion_km", "tipo": "decimal", "es_obligatorio": true, "orden": 0}]` | |
| `creado_por` | `esquemas_poliza` | UUID | No | Fijo | `4fa85f64-5717-4562-b3fc-2c963f66afa6` | |
| `created_at` | `esquemas_poliza` | DateTime (UTC) | Sí | Fijo | `2026-01-01T08:00:00Z` | |

---

## 2. Pendiente de Validar con la Product Owner

Los siguientes aspectos técnicos y de negocio no cuentan con una definición explícita o presentan casos especiales que requieren validación con la Product Owner:

1. **Tipos de Siniestro en Deducibles (`deducibles.tipo_siniestro`):**
   - Actualmente están tipificados en código los valores: `general`, `robo`, `choque` y `perdida_total` (SC-2026-001).
   - *Pregunta PO:* ¿Existen otros tipos contractuales que deban contemplarse (ej. `amparo_patrimonial`, `danos_maliciosos`, `fenomenos_naturales`) o la lista actual cubre todas las pólizas comercializadas?

2. **Nombres de Coberturas (`coberturas.nombre`):**
   - El modelo actual define `nombre` como texto libre (`String(255)`).
   - *Pregunta PO:* ¿Se mantendrá como texto abierto para cualquier producto o se requerirá un catálogo normalizado de coberturas (ej. `Muerte Accidental`, `Gastos Médicos`, `Auxilio Mecánico`)?

3. **Obligatoriedad de Inspección Previa (`polizas.inspeccion_id`):**
   - En la base de datos `inspeccion_id` es opcional (`nullable=True`), pero el campo `kilometraje_emision` en `polizas` es obligatorio (`nullable=False`).
   - *Pregunta PO:* ¿Bajo qué condiciones una póliza puede emitirse sin inspección física asociada (ej. vehículos 0 km de concesionario)?

4. **Clasificación y Reglas de Placas ANT:**
   - La regla técnica implementada deduce el tipo de servicio por la segunda letra (servicio público: A, U, Z; gubernamental: E, X, M, S; particular: resto).
   - *Pregunta PO:* ¿Es suficiente esta taxonomía para las operaciones del bróker o se requiere registrar explícitamente el uso del vehículo (ej. comercial, escolar, turismo)?

5. **Reglas de Campos Adicionales en Esquemas Dinámicos:**
   - `campos_adicionales` valida tipos básicos (`texto`, `numero`, `decimal`, `fecha`, `booleano`).
   - *Pregunta PO:* ¿Se prevé la necesidad de campos adicionales tipo lista/selección única o validaciones de rango numérico?
