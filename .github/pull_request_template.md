## Resumen
<!-- Describe brevemente el objetivo y alcance de este Pull Request -->

## Issue Jira
<!-- Referencia a la historia o defecto correspondiente -->
Closes SGD-

## Tipo de Cambio
- [ ] `feat`: Nueva funcionalidad
- [ ] `fix`: Corrección de defecto
- [ ] `refactor`: Refactorización de código sin alterar comportamiento
- [ ] `test`: Nuevas pruebas o mejoras de suite
- [ ] `chore`: Tareas de infraestructura, CI/CD o dependencias
- [ ] `docs`: Documentación técnica

## Cómo se Probó
<!-- Detalla comandos ejecutados, suites de prueba y pruebas manuales -->
- [ ] Pruebas unitarias y de integración (`pytest tests/`)
- [ ] Análisis estático backend (`ruff check backend`)
- [ ] Análisis y pruebas de cliente Flutter (`flutter analyze && flutter test`)
- [ ] Verificación de contrato OpenAPI (`python backend/scripts/export_openapi.py`)

## Checklist Definition of Done (DoD)
- [ ] El código cumple con las guías de estilo del repositorio.
- [ ] Se incluyeron pruebas automatizadas para los criterios de aceptación.
- [ ] No existen errores ni advertencias en linters/analizadores.
- [ ] `openapi.json` se encuentra sincronizado sin drift.
- [ ] Se actualizó el historial de cambios en `docs/UpdatesSprint1.md` si aplica.
- [ ] Se verificó el despliegue local con Docker Compose.

## Capturas / Evidencia Visual (Si aplica UI)
<!-- Adjuntar capturas de pantalla o grabaciones de la interfaz -->

## Riesgos o Plan de Rollback
<!-- Describe posibles impactos colaterales y la estrategia de reversión si algo falla -->
