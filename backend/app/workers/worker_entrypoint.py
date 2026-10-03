"""Worker entrypoint running all background worker loops and the health check probe."""

import asyncio
import logging
import signal

from app.workers.health import start_health_server_async
from app.workers.outbox_consumer import loop_consumidor_outbox
from app.workers.scheduler import loop_scheduler_diario
from app.workers.watchdog import loop_watchdog

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("sigad.worker")


async def main() -> None:
    """Entrypoint executing health server and background tasks."""
    logger.info("Initializing SIGAD background worker services...")
    # Start healthcheck server on port 8001 bound strictly to private container loopback
    await start_health_server_async(host="127.0.0.1", port=8001)

    # Run background loops concurrently
    tasks = [
        asyncio.create_task(loop_consumidor_outbox()),
        asyncio.create_task(loop_scheduler_diario()),
        asyncio.create_task(loop_watchdog()),
    ]

    stop_event = asyncio.Event()

    def _handle_stop(*_: object) -> None:
        logger.info("Termination signal received in worker entrypoint.")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _handle_stop)
        except (NotImplementedError, RuntimeError):
            pass

    # Wait until stop or any fatal error
    wait_stop = asyncio.create_task(stop_event.wait())
    done, pending = await asyncio.wait(
        [wait_stop, *tasks],
        return_when=asyncio.FIRST_COMPLETED,
    )

    for task in pending:
        task.cancel()

    await asyncio.gather(*pending, return_exceptions=True)
    logger.info("SIGAD background worker shutdown complete.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        logger.info("Worker stopped.")
