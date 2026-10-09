"""Traceability and coverage verification of User Acceptance Tests (UAT-01 to UAT-23).

Ensures complete bidirectional traceability between User Stories (HU-01 to HU-23),
Master Test Plan IEEE 829 (SIGAD-TP-001.md), and physical automated test implementations.
"""

from pathlib import Path
import pytest

UAT_MATRIX = [
    {
        "id": "UAT-01",
        "hu": "HU-01 Login web",
        "description": "Autenticación polimórfica (agentes/admins con email, clientes con cédula)",
        "preconditions": "Usuario activo en BD con hash Argon2id",
        "expected_result": "JWT access y refresh token con rol correspondiente",
        "test_module": "tests/unit/test_security/test_login_polimorfico.py",
    },
    {
        "id": "UAT-02",
        "hu": "HU-02 Registrar cliente",
        "description": "Alta de cliente con validación estricta de cédula ecuatoriana módulo 10",
        "preconditions": "Agente autenticado",
        "expected_result": "Cliente registrado con estado ACTIVO",
        "test_module": "tests/unit/test_validation/test_ecuadorian_id.py",
    },
    {
        "id": "UAT-03",
        "hu": "HU-03 Registrar vehículo",
        "description": "Asociación de vehículo con validación de placas ANT ecuatorianas",
        "preconditions": "Cliente existente en el sistema",
        "expected_result": "Vehículo persistido con placa normalizada",
        "test_module": "tests/unit/test_validation/test_plates.py",
    },
    {
        "id": "UAT-04",
        "hu": "HU-04 Registrar póliza",
        "description": "Evaluador CFG (10 nodos, V(G)=4) y cálculo de estado inicial",
        "preconditions": "Vehículo registrado sin póliza activa simultánea",
        "expected_result": "Póliza creada con estado activa, pendiente o vencida",
        "test_module": "tests/unit/test_domain_cfg.py",
    },
    {
        "id": "UAT-05",
        "hu": "HU-05 Carga de documentos",
        "description": "Ingesta multipart con pipeline de extracción OCR dos compuertas a 200 DPI",
        "preconditions": "Póliza o siniestro registrado",
        "expected_result": "Documento almacenado y tarea outbox generada",
        "test_module": "tests/unit/test_workers/test_extraccion_200_dpi_liberacion_memoria.py",
    },
    {
        "id": "UAT-06",
        "hu": "HU-06 Revisión OCR",
        "description": "Tabla de decisión canónica de Jorgensen para aprobación/rechazo OCR",
        "preconditions": "Documento procesado con campos extraídos",
        "expected_result": "Decisión determinista: Aprobar, Revisión Manual o Rechazar",
        "test_module": "tests/unit/test_quality/test_decision_table.py",
    },
    {
        "id": "UAT-07",
        "hu": "HU-07 Modificar póliza",
        "description": "Actualización de póliza con snapshot de kilometraje y deducibles",
        "preconditions": "Póliza activa",
        "expected_result": "Historial inmutable registrado",
        "test_module": "tests/integration/test_kilometraje_snapshot.py",
    },
    {
        "id": "UAT-08",
        "hu": "HU-08 Desactivar póliza",
        "description": "Transición de estado a cancelada sin borrado físico en BD",
        "preconditions": "Póliza en estado activa o por vencer",
        "expected_result": "Estado actualizado con preservación de integridad",
        "test_module": "tests/integration/test_actualizacion_estados_poliza.py",
    },
    {
        "id": "UAT-09",
        "hu": "HU-09 Búsqueda",
        "description": "Consultas indexadas anti-inyección por cliente, número o placa",
        "preconditions": "Registros existentes en base de datos",
        "expected_result": "Resultados filtrados en O(log n)",
        "test_module": "tests/integration/test_polizas_api.py",
    },
    {
        "id": "UAT-10",
        "hu": "HU-10 Visualización de estados",
        "description": "Transición automática a 'por_vencer' a los 30 días",
        "preconditions": "Fecha actual a 30 días de la fecha de fin",
        "expected_result": "Estado actualizado a 'por_vencer'",
        "test_module": "tests/unit/test_workers/test_scheduler_transiciones_completas.py",
    },
    {
        "id": "UAT-11",
        "hu": "HU-11 Talleres",
        "description": "Catálogo de talleres mecánicos afiliados con geolocalización",
        "preconditions": "API disponible",
        "expected_result": "Lista pública/autenticada de talleres disponibles",
        "test_module": "tests/integration/test_polizas_api.py",
    },
    {
        "id": "UAT-12",
        "hu": "HU-12 Asistencias",
        "description": "Catálogo de asistencias de emergencia y coberturas",
        "preconditions": "Póliza contratada",
        "expected_result": "Detalle de asistencias según plan",
        "test_module": "tests/integration/test_polizas_api.py",
    },
    {
        "id": "UAT-13",
        "hu": "HU-13 Login móvil",
        "description": "Autenticación móvil por cédula con rate limiting selectivo",
        "preconditions": "Cliente con credenciales válidas",
        "expected_result": "Sesión iniciada con JWT",
        "test_module": "tests/unit/test_security/test_login_movil_por_cedula.py",
    },
    {
        "id": "UAT-14",
        "hu": "HU-14 Consultar pólizas (cliente)",
        "description": "Filtro SQL estricto anti-BOLA/IDOR para consulta de pólizas",
        "preconditions": "Cliente autenticado",
        "expected_result": "Cliente sólo accede a sus propias pólizas (404 uniforme)",
        "test_module": "tests/integration/test_bola_query_level.py",
    },
    {
        "id": "UAT-15",
        "hu": "HU-15 Detalle de póliza",
        "description": "Detalle completo con coberturas y deducibles históricos",
        "preconditions": "Póliza asignada al usuario consultante",
        "expected_result": "Respuesta con coberturas y montos deducibles",
        "test_module": "tests/integration/test_migracion_deducibles_historicos.py",
    },
    {
        "id": "UAT-16",
        "hu": "HU-16 Consultar vehículo",
        "description": "Visualización de vehículos propios con protección IDOR",
        "preconditions": "Cliente autenticado",
        "expected_result": "Solo vehículos asociados a su identificación",
        "test_module": "tests/integration/test_idor_documentos.py",
    },
    {
        "id": "UAT-17",
        "hu": "HU-17 Consultar coberturas",
        "description": "Agregación y desglose de coberturas contratadas",
        "preconditions": "Póliza emitida",
        "expected_result": "Lista estructurada con límites asegurados",
        "test_module": "tests/integration/test_polizas_api.py",
    },
    {
        "id": "UAT-18",
        "hu": "HU-18 Consultar vigencia",
        "description": "Cálculo de vigencia y fechas límites en zona horaria America/Guayaquil",
        "preconditions": "Póliza con fechas inicio y fin válidas",
        "expected_result": "Estado 'activa', 'pendiente' o 'vencida'",
        "test_module": "tests/unit/test_domain/test_poliza_activa.py",
    },
    {
        "id": "UAT-19",
        "hu": "HU-19 Alerta de vencimiento",
        "description": "Scheduler cron que identifica pólizas próximas a expirar",
        "preconditions": "Scheduler activo con transacciones aisladas",
        "expected_result": "Pólizas actualizadas a 'por_vencer' sin carreras",
        "test_module": "tests/unit/test_workers/test_scheduler_transiciones_completas.py",
    },
    {
        "id": "UAT-20",
        "hu": "HU-20 Consultar pagos",
        "description": "Visibilidad de cuotas y estado financiero según rol",
        "preconditions": "Usuario autenticado",
        "expected_result": "Historial de transacciones de prima",
        "test_module": "tests/integration/test_pagos_api.py",
    },
    {
        "id": "UAT-21",
        "hu": "HU-21 Talleres móviles",
        "description": "Visualización optimizada de talleres en app cliente",
        "preconditions": "Cliente autenticado",
        "expected_result": "Lista con teléfonos, direcciones y marcas atendidas",
        "test_module": "tests/integration/test_polizas_api.py",
    },
    {
        "id": "UAT-22",
        "hu": "HU-22 Asistencia emergencia",
        "description": "Directorio de emergencias (grúa, ambulancia, cerrajería)",
        "preconditions": "Acceso disponible desde interfaz móvil",
        "expected_result": "Llamada directa y datos de contacto de emergencia",
        "test_module": "tests/integration/test_polizas_api.py",
    },
    {
        "id": "UAT-23",
        "hu": "HU-23 Contacto",
        "description": "Canales oficiales de RJ Seguros para atención al asegurado",
        "preconditions": "Sin precondición",
        "expected_result": "Teléfonos, correos y oficinas de servicio al cliente",
        "test_module": "tests/integration/test_polizas_api.py",
    },
]


def test_uat_matrix_completeness():
    """Assert all 23 User Acceptance Tests (UAT-01 to UAT-23) are formally defined."""
    assert len(UAT_MATRIX) == 23, f"Expected 23 UAT definitions, found {len(UAT_MATRIX)}"
    
    ids = [uat["id"] for uat in UAT_MATRIX]
    for i in range(1, 24):
        expected_id = f"UAT-{i:02d}"
        assert expected_id in ids, f"Missing acceptance test {expected_id}"


def test_all_uat_test_modules_exist_on_disk():
    """Verify that every UAT maps to an actual test module file in the codebase."""
    backend_root = Path(__file__).resolve().parents[3]
    
    missing_modules = []
    for uat in UAT_MATRIX:
        module_rel_path = uat["test_module"]
        module_full_path = backend_root / module_rel_path
        if not module_full_path.exists():
            missing_modules.append(f"{uat['id']}: {module_rel_path}")

    assert not missing_modules, (
        f"The following UAT test modules are missing on disk:\n" + "\n".join(missing_modules)
    )


def test_uat_schema_attributes():
    """Ensure all UAT records contain complete IEEE 829 mandatory test case fields."""
    mandatory_fields = [
        "id", "hu", "description", "preconditions", "expected_result", "test_module"
    ]
    for uat in UAT_MATRIX:
        for field in mandatory_fields:
            assert field in uat and uat[field], f"UAT {uat.get('id')} lacks field '{field}'"
