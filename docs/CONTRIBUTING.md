# Guía de Contribución y Convenciones de Desarrollo (SIGAD)

Este documento define el ciclo de vida del código, las convenciones de ramificación, control de versiones semántico, estructura de commits y los acuerdos de Definition of Ready (DoR) y Definition of Done (DoD) para el proyecto SIGAD.

---

## 1. Convención de Ramas (Git Flow)

El desarrollo del repositorio sigue un esquema estructurado para garantizar estabilidad y trazabilidad:

* **`main` (Producción):**
  - Rama protegida con la versión estable y desplegable a producción.
  - Merge exclusivo mediante Pull Request (PR) con suite de CI completa en verde y al menos una aprobación de revisión de código.
* **`v2` / `develop` (Integración):**
  - Rama de integración continua y estabilización de entregas activas.
* **`feature/SGD-<n>-<slug>`:**
  - Nuevas características o historias de usuario derivadas del backlog (ejemplo: `feature/SGD-59-crud-clientes`).
* **`fix/SGD-<n>-<slug>`:**
  - Corrección de bugs o defectos reportados en Jira (ejemplo: `fix/SGD-68-404-uniforme`).
* **`chore/<slug>`:**
  - Tareas de mantenimiento, dependencias o infraestructura (ejemplo: `chore/actualizar-caddyfile`).
* **`release/vX.Y.Z`:**
  - Congelamiento de código previo al despliegue de una versión mayor o menor.
* **`hotfix/vX.Y.Z`:**
  - Parches críticos aplicados directamente contra `main` y sincronizados inmediatamente a `develop`.

---

## 2. Versionado Semántico y Tags

El repositorio utiliza [Semantic Versioning 2.0.0](https://semver.org/) bajo la nomenclatura `vMAJOR.MINOR.PATCH`:

* **`MAJOR` (vX.0.0):** Cambios que rompen compatibilidad en contratos de API, base de datos o arquitectura general.
* **`MINOR` (v0.X.0):** Adición de nuevas funcionalidades e historias de usuario compatibles hacia atrás.
* **`PATCH` (v0.0.X):** Correcciones de errores, parches de seguridad y optimizaciones compatibles.

> [!NOTE]
> Cada creación y push de un tag con formato `v*.*.*` dispara de forma automática el pipeline de CI (`publish-ghcr`) para compilar y publicar la imagen oficial `ghcr.io/xavih830/sigadbackend:vX.Y.Z` en GitHub Packages.

---

## 3. Convención de Commits Atómicos

Para asegurar revisiones limpias y trazabilidad punto a punto, los commits deben ser atómicos y seguir Conventional Commits en español.

* Consulta los lineamientos y ejemplos detallados en el [README.md §1](file:///c:/Users/xhcg2/OneDrive/Escritorio/X/Proyectos_personales/SIGAD/README.md#1-gu%C3%ADa-de-commits-at%C3%B3micos-y-buenas-pr%C3%A1cticas-git).
* **Vinculación con Jira:** Cada commit asociado a una historia de usuario o bug debe incluir la referencia de Jira en el cuerpo del mensaje:
  ```text
  feat(clientes): validar ruc ecuatoriano ademas de cedula

  Acepta personas naturales, sociedades publicas y privadas segun modulo 11.

  Refs: SGD-59
  ```

---

## 4. Definition of Ready (DoR)

Una historia de usuario o requerimiento solo puede ingresar a un Sprint si satisface todas las condiciones de la Definition of Ready:

1. **Formato Estándar:** Redactada con la plantilla *"Como [rol], quiero [funcionalidad] para [beneficio]"*.
2. **Criterios de Aceptación:** Especificados de forma verificable y unívoca (BDD / Gherkin o checklist de comportamiento).
3. **Estimación:** Historia estimada y acordada en Story Points por el equipo técnico.
4. **Dependencias Identificadas:** Ausencia de bloqueos externos o dependencias no resueltas.
5. **Diseño / Prototipos:** Vistas, flujos de interacción o diagramas UI provistos si la historia incluye frontend.
6. **Datos de Prueba:** Casos límite, identificaciones o archivos mock disponibles para validar el flujo.
7. **Acotamiento:** Alcance factible de completarse íntegramente dentro de la duración del sprint.

---

## 5. Definition of Done (DoD)

Una tarea o historia de usuario se considera terminada ("Done") únicamente cuando:

1. **Revisión de Código:** Pull Request revisado y aprobado por pares sin comentarios bloqueantes pendientes.
2. **Calidad Estática:** Cero advertencias ni errores en linters (`ruff check backend`, `flutter analyze`).
3. **Pruebas Automatizadas:** 100% de pruebas en verde (`pytest`, `flutter test`), incluyendo pruebas unitarias e integración de los nuevos criterios de aceptación.
4. **Contrato OpenAPI Sincronizado:** Ausencia de drift en `openapi.json` validado herméticamente.
5. **Historial de Actualizaciones:** Registro documentado en `docs/UpdatesSprint1.md` al cierre de la fase correspondiente.
6. **Despliegue y Validación:** Despliegue validado localmente mediante `docker compose up --build` o verificado en el entorno de staging.
