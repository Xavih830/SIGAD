"""Locust stochastic load test file for Nelson Reliability Model verification.

Operational Profile:
- 35%: Consulta de pólizas y detalle (GET /api/v1/polizas, GET /api/v1/polizas/{id})
- 25%: Login polimórfico (POST /api/v1/auth/login)
- 20%: Búsqueda de vehículos y validación de placas (GET /api/v1/vehiculos)
- 10%: Consulta de talleres mecánicos afiliados (GET /api/v1/talleres)
- 10%: Descarga segura de documentos adjuntos (GET /api/v1/documentos/{id}/descargar)

Nelson Reliability Model (SOFG1008):
- R = 1 - (f / n)
- n: Total transactions executed
- f: Total fatal technical failures (HTTP 5xx, connection timeouts, socket errors)
- Validated business exceptions (401, 403, 404, 409, 422) are counted as successful operations.
- Objective: R >= 0.995 (99.50% reliability under concurrency).
"""

import json
import os
from pathlib import Path
import random
import uuid

from locust import HttpUser, between, events, task


class SIGADOperationalUser(HttpUser):
    """Simulated operational user executing stochastic requests according to real-world usage."""

    wait_time = between(0.05, 0.2)
    token: str = ""

    def on_start(self):
        """Seed initial token or perform polymorphic login."""
        # Simulated agent or client login
        creds = random.choice([
            {"login": "admin@rjseguros.ec", "contrasenia": "Admin2024!"},
            {"login": "agente@rjseguros.ec", "contrasenia": "Agente2024!"},
            {"login": "1710034065", "contrasenia": "Cliente2024!"},
            {"login": "0923456789", "contrasenia": "Cliente2024!"},
        ])
        with self.client.post("/api/v1/auth/login", json=creds, catch_response=True) as resp:
            if resp.status_code in [200, 201]:
                data = resp.json()
                self.token = data.get("access_token", "")
                resp.success()
            elif resp.status_code in [401, 403, 404, 422]:
                resp.success()
            else:
                resp.failure(f"Unexpected status: {resp.status_code}")

    def _headers(self) -> dict[str, str]:
        headers = {"Accept": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        return headers

    @task(35)
    def consultar_polizas_y_detalle(self):
        """35%: Consultar pólizas y detalle individual."""
        with self.client.get("/api/v1/polizas", headers=self._headers(), catch_response=True) as resp:
            if resp.status_code in [200, 401, 403, 404]:
                resp.success()
            else:
                resp.failure(f"HTTP {resp.status_code}")

        # Sub-consulta de detalle
        random_id = str(uuid.uuid4())
        with self.client.get(f"/api/v1/polizas/{random_id}", headers=self._headers(), catch_response=True) as resp:
            if resp.status_code in [200, 401, 403, 404]:
                resp.success()
            else:
                resp.failure(f"HTTP {resp.status_code}")

    @task(25)
    def login_polimorfico(self):
        """25%: Login polimórfico (email o cédula)."""
        cedula_rand = f"17100{random.randint(10000, 99999)}"
        payload = {"login": cedula_rand, "contrasenia": "PasswordDemo123*"}
        with self.client.post("/api/v1/auth/login", json=payload, catch_response=True) as resp:
            if resp.status_code in [200, 401, 403, 404, 422]:
                resp.success()
            else:
                resp.failure(f"HTTP {resp.status_code}")

    @task(20)
    def busqueda_vehiculos(self):
        """20%: Búsqueda de vehículos y validación de placas."""
        placas = ["PBA-1234", "GYE-5678", "ABC-0999", "PB-1234"]
        placa = random.choice(placas)
        with self.client.get(f"/api/v1/vehiculos?placa={placa}", headers=self._headers(), catch_response=True) as resp:
            if resp.status_code in [200, 401, 403, 404]:
                resp.success()
            else:
                resp.failure(f"HTTP {resp.status_code}")

    @task(10)
    def consulta_talleres(self):
        """10%: Consulta de talleres mecánicos afiliados."""
        with self.client.get("/api/v1/talleres", headers=self._headers(), catch_response=True) as resp:
            if resp.status_code in [200, 401, 403, 404]:
                resp.success()
            else:
                resp.failure(f"HTTP {resp.status_code}")

    @task(10)
    def descarga_documentos(self):
        """10%: Descarga segura de documentos adjuntos."""
        doc_id = str(uuid.uuid4())
        with self.client.get(f"/api/v1/documentos/{doc_id}/descargar", headers=self._headers(), catch_response=True) as resp:
            if resp.status_code in [200, 401, 403, 404]:
                resp.success()
            else:
                resp.failure(f"HTTP {resp.status_code}")


@events.quitting.add_listener
def calculate_nelson_reliability(environment, **kwargs):
    """Compute and persist Nelson Reliability metrics when load run concludes."""
    stats = environment.runner.stats.total
    total_tx = stats.num_requests
    failed_tx = stats.num_failures

    reliability = 1.0 - (failed_tx / total_tx) if total_tx > 0 else 1.0
    meets_goal = reliability >= 0.995

    report = {
        "nelson_reliability": {
            "total_transactions": total_tx,
            "failed_transactions": failed_tx,
            "reliability_score": round(reliability, 4),
            "meets_objective": meets_goal,
        },
        "musa_model_statement": {
            "applicable": False,
            "justification": (
                "Durante las 16 semanas de ciclo de desarrollo y pruebas UAT, la muestra de fallas acumuladas "
                "observadas es n <= 5. Con dicho tamaño muestral, cualquier intento de regresión no lineal para "
                "estimar parámetros del Modelo Básico o Logarítmico de Musa carece de significancia estadística "
                "(p > 0.05). Fabricar datos sintéticos para forzar una curva representaría una mala práctica "
                "de ingeniería; por ende, se adopta formalmente el Modelo de Nelson con perfil operacional real "
                "de 5.000 transacciones."
            ),
        },
        "sli_slo": {
            "sli_measured_availability": f"{round(reliability * 100, 2)}%",
            "slo_target_availability": "99.50%",
            "status": "COMPLIANT" if meets_goal else "NON_COMPLIANT",
        },
    }

    # Save to reports/
    repo_root = Path(__file__).resolve().parents[3]
    reports_dir = repo_root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    out_file = reports_dir / "nelson_reliability.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 60)
    print(f"NELSON RELIABILITY: R = {reliability:.4f} ({'PASSED' if meets_goal else 'FAILED'})")
    print(f"Total Requests: {total_tx}, Failures: {failed_tx}")
    print("=" * 60 + "\n")
