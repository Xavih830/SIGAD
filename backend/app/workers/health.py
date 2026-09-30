"""Worker healthcheck service — lightweight HTTP server on port 8001."""

import asyncio
from typing import Any
from fastapi import FastAPI
import uvicorn

worker_app = FastAPI(
    title="SIGAD Worker Health",
    description="Independent worker healthcheck probe",
    version="1.0.0",
)


@worker_app.get("/health")
async def get_worker_health() -> dict[str, str]:
    """Returns worker status ok for Docker / orchestrator health probes."""
    return {"status": "ok", "worker": "running"}


def run_health_server(host: str = "0.0.0.0", port: int = 8001) -> None:
    """Run worker health server synchronously."""
    uvicorn.run(worker_app, host=host, port=port, log_level="warning")


async def start_health_server_async(host: str = "0.0.0.0", port: int = 8001) -> uvicorn.Server:
    """Start uvicorn worker health server in asyncio background task."""
    config = uvicorn.Config(app=worker_app, host=host, port=port, log_level="warning")
    server = uvicorn.Server(config)
    asyncio.create_task(server.serve())
    # Allow short spin-up
    await asyncio.sleep(0.2)
    return server


if __name__ == "__main__":
    run_health_server()
