"""Worker healthcheck service — lightweight HTTP server on port 8001."""

import asyncio
import logging
import time

from fastapi import FastAPI
from fastapi.responses import JSONResponse
import uvicorn

from app.services.resilient_pool import resilient_pool

logger = logging.getLogger("sigad.worker.health")

worker_app = FastAPI(
    title="SIGAD Worker Health",
    description="Independent worker healthcheck probe",
    version="1.0.0",
)


_worker_health_cache: dict[str, str | float] = {"status": "unknown", "timestamp": 0.0}
_CACHE_TTL = 3.0


@worker_app.get("/health/live")
async def get_worker_liveness() -> dict[str, str]:
    """Liveness probe: returns worker process status immediately."""
    return {"status": "ok", "worker": "running"}


@worker_app.get("/health", response_model=None)
@worker_app.get("/health/ready", response_model=None)
async def get_worker_health() -> JSONResponse | dict[str, str]:
    """Returns worker status ok and validates that ProcessPool is active."""
    now = time.monotonic()
    if now - _worker_health_cache["timestamp"] < _CACHE_TTL and _worker_health_cache["status"] == "active":
        return {"status": "ok", "worker": "running", "pool": "active"}

    try:
        loop = asyncio.get_running_loop()
        await asyncio.wait_for(
            loop.run_in_executor(resilient_pool.pool, abs, 1),
            timeout=2.0,
        )
        _worker_health_cache["status"] = "active"
        _worker_health_cache["timestamp"] = now
        return {"status": "ok", "worker": "running", "pool": "active"}
    except Exception as e:
        logger.error("worker_health_probe_failed: %s", str(e))
        _worker_health_cache["status"] = "unhealthy"
        _worker_health_cache["timestamp"] = 0.0
        return JSONResponse(
            status_code=503,
            content={"status": "degraded", "worker": "running", "pool": "unhealthy"},
        )


def run_health_server(host: str = "127.0.0.1", port: int = 8001) -> None:
    """Run worker health server synchronously."""
    uvicorn.run(worker_app, host=host, port=port, log_level="warning")


async def start_health_server_async(host: str = "127.0.0.1", port: int = 8001) -> uvicorn.Server:
    """Start uvicorn worker health server in asyncio background task."""
    config = uvicorn.Config(app=worker_app, host=host, port=port, log_level="warning")
    server = uvicorn.Server(config)
    asyncio.create_task(server.serve())
    await asyncio.sleep(0.2)
    return server


if __name__ == "__main__":
    run_health_server()
