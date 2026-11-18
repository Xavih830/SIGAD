# Contratos de Datos para Integración con SICAS (SIGAD)

Contratos canónicos de intercambio JSON para **Cliente**, **Vehículo** y **Póliza**, derivados de `openapi.json` y del diccionario `docs/campos-poliza.md`.

---

## 1. Contrato de Cliente (`ClienteCreate` / `ClienteResponse`)

| Campo | Tipo | Obligatorio (Creación) | Descripción / Reglas |
|---|---|---|---|
| `id` | `string (uuid)` | Solo respuesta | Identificador único del cliente. |
| `identificacion` | `string` | Sí | Cédula ecuatoriana (10 dígitos) o RUC (13 dígitos, regla SRI). Inmutable tras creación. |
| `nombres` | `string` | Sí | Nombre completo o razón social (2–255 caracteres). |
| `email` | `string (email)` | No | Correo electrónico de contacto. |
| `telefono` | `string` | No | Número de teléfono de contacto. |
| `usuario_id` | `string (uuid)` | Solo respuesta | Usuario vinculado para acceso móvil (si fue activado). |
| `created_at` | `string (date-time)` | Solo respuesta | Marca temporal UTC de creación. |

### Ejemplo JSON (`ClienteCreate`)
```json
{
  "identificacion": "1710034065001",
  "nombres": "Comercializadora Andina S.A.",
  "email": "contacto@andina.ec",
  "telefono": "0991234567"
}
```

---

## 2. Contrato de Vehículo (`VehiculoCreate` / `VehiculoResponse`)

| Campo | Tipo | Obligatorio (Creación) | Descripción / Reglas |
|---|---|---|---|
| `id` | `string (uuid)` | Solo respuesta | Identificador único del vehículo. |
| `cliente_id` | `string (uuid)` | Sí | Propietario del vehículo. |
| `placa` | `string` | Sí | Placa ecuatoriana ANT (`ABC-123`, `ABC-1234` o moto `AB-123C`). |
| `tipo_placa` | `enum` | Solo respuesta | Clasificación ANT: `particular`, `servicio_publico`, `gubernamental`, `moto`. |
| `marca` | `string` | Sí | Marca del vehículo (ej. `Chevrolet`). |
| `modelo` | `string` | Sí | Modelo del vehículo (ej. `D-Max`). |
| `anio` | `integer` | Sí | Año de fabricación (1950–2027). |
| `motor` | `string` | Sí en creación | Número de serie del motor (máx. 30 caracteres). |
| `chasis` | `string` | Sí en creación | Número de chasis/VIN único (máx. 30 caracteres). |
| `color` | `string` | Sí en creación | Color principal del vehículo (máx. 30 caracteres). |
| `created_at` | `string (date-time)` | Solo respuesta | Marca temporal UTC de creación. |

### Ejemplo JSON (`VehiculoCreate`)
```json
{
  "cliente_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "placa": "PBA-1234",
  "marca": "Toyota",
  "modelo": "Corolla",
  "anio": 2024,
  "motor": "2ZR-1234567",
  "chasis": "9BRBL3HE5P0123456",
  "color": "BLANCO"
}
```

---

## 3. Contrato de Póliza (`PolizaCreate` / `PolizaUpdate` / `PolizaResponse`)

| Campo | Tipo | Obligatorio (Creación) | Descripción / Reglas |
|---|---|---|---|
| `id` | `string (uuid)` | Solo respuesta | Identificador único de la póliza. |
| `numero_poliza` | `string` | Sí | Número contractual único (3–50 caracteres). |
| `cliente_id` | `string (uuid)` | Sí | Cliente titular de la póliza. |
| `vehiculo_id` | `string (uuid)` | Sí | Vehículo asegurado. |
| `inspeccion_id` | `string (uuid)` | No | Inspección previa asociada. |
| `esquema_id` | `string (uuid)` | No | Esquema dinámico de campos adicionales (`esquemas_poliza`). |
| `fecha_inicio` | `string (date)` | Sí | Inicio de vigencia (`YYYY-MM-DD`). |
| `fecha_fin` | `string (date)` | Sí | Fin de vigencia (`YYYY-MM-DD`, máximo 5 años desde `fecha_inicio`). |
| `estado` | `enum` | Solo respuesta | `activa`, `vencida`, `pendiente`, `cancelada`. |
| `valor_asegurado` | `decimal (> 0)` | Sí | Valor comercial asegurado en USD. |
| `prima_mensual` | `decimal (> 0)` | Sí | Prima mensual en USD. |
| `kilometraje_emision` | `integer (>= 0)` | Sí | Snapshot contractual inmutable del odómetro al emitir. |
| `campos_adicionales` | `object` | No | Diccionario dinámico validado contra `esquema_id`. |
| `coberturas` | `array[CoberturaCreate]` | No | Lista de coberturas `{nombre, monto}`. |
| `deducibles` | `array[DeducibleCreate]` | No | Si se omite, se genera deducible general por defecto (10%, mín. \$200). |
| `version` | `integer` | Sí en `PUT` | Control optimista de concurrencia (inicia en `1`). |

### Ejemplo JSON (`PolizaCreate`)
```json
{
  "numero_poliza": "POL-2026-001234",
  "cliente_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "vehiculo_id": "c9a85f64-5717-4562-b3fc-2c963f66afa6",
  "fecha_inicio": "2026-11-17",
  "fecha_fin": "2027-11-17",
  "valor_asegurado": "25000.00",
  "prima_mensual": "120.00",
  "kilometraje_emision": 18200,
  "coberturas": [
    { "nombre": "Responsabilidad Civil", "monto": "50000.00" }
  ]
}
```
