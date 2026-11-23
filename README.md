# SIGAD

**Vehicle Insurance Policy Management and Document Analysis System**

Midterm project · Software Engineering II (SOFG1008) · ESPOL · 2026
Team **SE2-P3-SIGAD** · Client: **RJ Seguros** (insurance brokerage, Guayaquil)

Live demo: https://sigad.duckdns.org · Downloads: https://sigad.duckdns.org/descargas/

---

## Overview

RJ Seguros manages client, vehicle and policy data across scattered files and manually transcribes the PDFs issued by insurers. SIGAD centralizes that information and extracts data from policy PDFs automatically.

One system, two platforms:

| Platform | Users | Technology |
| --- | --- | --- |
| Web | Administrative staff (admin, agent) | Flutter Web |
| Android app | Policyholders (client) | Flutter Android (shared codebase) |
| Shared backend | Policies, clients, documents | FastAPI + PostgreSQL |

Main capabilities: centralized insurance operations, role-based access (admin, agent, client) and automatic PDF information extraction.

## Architecture

```
Flutter Web (BLoC · ApiClient) ─┐
                                ├─► Caddy + FastAPI ─► PostgreSQL 16 (SQLAlchemy · audit triggers)
Flutter Android (shared code) ──┘          │
                                           └─► PDF Worker (isolated extraction)
```

- **Frontend:** Flutter (BLoC, ApiClient), one codebase for web and Android.
- **Backend:** FastAPI with a service layer, SQLAlchemy, versioned migrations (Alembic).
- **Database:** PostgreSQL 16 with audit triggers for change traceability.
- **PDF Worker:** separate process pool; jobs over 120 s are killed with SIGKILL and the pool is recreated.
- **Edge:** Caddy terminates TLS, adds security headers, serves the web build and is the only service exposed to the Internet.
- **Deployment:** Docker Compose locally; Google Cloud VM for public testing. API, worker and database run on internal Docker networks with memory limits.

## Security and reliability

- Argon2id password hashing
- Token rotation for session protection
- Uniform `404` for missing and inaccessible records (access isolation)
- Audit triggers on data changes
- Isolated PDF worker for resilience
- Secure upload: 15 MB limit, magic-byte validation, malformed-file handling
- HTTPS through Caddy

## PDF processing flow

`Upload → Validate → Process → Extract → Check → Result`

## Roadmap and status

| Sprint | Focus | Status |
| --- | --- | --- |
| 01 | Secure access: login, clients, vehicles | Delivered (v0.1.0, 31/39 SP at review, CI tasks deferred) |
| 02 | Policy lifecycle: policies, PDFs, inspection | Delivered (27/50 SP at review, 45/50 after Nov 17 follow-up) |
| 03 | Automation: OCR review, payments, schedulers | Planned |
| 04 | Release: reliability, UAT, v1.0.0 | Planned |

## Testing and quality

Risk-driven strategy: 23 risks identified, 9 high-priority (exposure = probability × impact).

- **Techniques:** equivalence partitioning (Ecuadorian IDs and plates), boundary value analysis (five-year validity, 15 MB uploads), decision tables (policy status), control and data flow.
- **Traceability:** User Story → Risk → Acceptance Criterion → Test Case (e.g. HU-07 → R-14 → AC-07-3 → TC-S2-03).
- **Results at v0.2.0:**
  - Backend: 328 / 332 tests passed (98.8%), 80% line coverage. The 4 failures are environment/branch configuration issues.
  - Flutter: 56 / 56 tests passed, 22.36% line coverage.
- **Static analysis:** extended Ruff findings 167 → 140 in Sprint 2; `flutter analyze` reports 0 issues.
- **Inspection:** IEEE 1028 formal inspection with signed records (November 19, 2026).

## Getting started

> Replace the commands below with the ones from your repository.

```bash
# 1. Clone
git clone <repository-url>
cd <repository-folder>

# 2. Configure environment variables
cp .env.example .env

# 3. Start the stack (API, worker, database, Caddy)
docker compose up --build

# 4. Run backend tests
docker compose exec api pytest

# 5. Run Flutter tests
cd frontend && flutter test
```

Evaluation credentials are provided in the project report (Appendix B) and are not stored in this repository.

## Team

| Member | Area |
| --- | --- |
| Carlos Ronquillo | Validation and boundary tests |
| Cristhian Vinces | Audit and infrastructure |
| Leonardo Macías | Navigation and policy details |
| Manuel Matute | Policy UI and control flow |
| Steven Lino | Authentication and PDF worker |
| Xavier Camacho | Backend and security |

Product Owner (RJ Seguros): Ariana Guerrón
Instructor: Ing. Ángela Isabel Carrera Rivera

## License

Academic project developed for ESPOL. Add a license here if the repository will be made public.
