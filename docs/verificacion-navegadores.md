# Checklist de Verificación de Compatibilidad en Navegadores Web (SGD-58)

Este documento registra los resultados de validación manual en los principales navegadores web soportados por SIGAD, asegurando que la renderización con CanvasKit local, autenticación, navegación y gestión de sesión operen de manera idéntica y sin violaciones de CSP.

## Tabla de Verificación de Compatibilidad

| Navegador | Versión | Fecha | Login OK | Dashboard OK | Registro Cliente OK | Sesión Expirada OK | Responsable |
|---|---|---|:---:|:---:|:---:|:---:|---|
| **Google Chrome** | | | [ ] | [ ] | [ ] | [ ] | |
| **Mozilla Firefox** | | | [ ] | [ ] | [ ] | [ ] | |
| **Apple Safari** | | | [ ] | [ ] | [ ] | [ ] | |

---

### Instrucciones de Verificación Manual
1. Compilar la aplicación web con CanvasKit local:
   ```bash
   flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env.client
   ```
2. Servir el artefacto a través del gateway Caddy con cabeceras de producción (`docker compose up -d`).
3. Acceder al portal en cada navegador y verificar:
   - **Login OK:** Inicio de sesión con credenciales administrativas y credenciales inválidas (mostrar error correctamente).
   - **Dashboard OK:** Carga correcta de pestañas, tablas (`SigadDataTable`), fuentes y componentes visuales sin advertencias de CSP en la consola de herramientas de desarrollo.
   - **Registro Cliente OK:** Apertura de modal de formulario, validación de campos y guardado exitoso.
   - **Sesión Expirada OK:** Cierre o expiración de token con redirección automática a la vista de login y muestra del SnackBar de sesión expirada.
4. Marcar con `[x]` las casillas verificadas y registrar la versión del navegador, fecha y firma del responsable.
