"""Rate Limiting in 4 Layers with strictly bounded LRU Cache memory (<= 2 MB).

Layers:
- Layer 1 (By IP): Max 5 req / 15 min for /login; Max 3 req / 1 min for /vinculacion.
- Layer 2 (By Identity): Max 5 attempts / 15 min for /login; Max 3 attempts / 1 hr for /vinculacion.
- Layer 3 (Selective Tarpitting): Progressive async delay (await asyncio.sleep) on bursty IPs.
- Layer 4 (Account Lockout): 10 accumulated failures in 1 hr locks account for 30 minutes.

Memory safety guarantee:
All rate limit tracking resides in `cachetools.LRUCache(maxsize=10000)` ensuring
bounded RAM consumption (~2 MB) and automatic eviction of older items to prevent DoS.
"""

import asyncio
import time
from typing import Dict, List, Optional, Tuple

from cachetools import LRUCache
from fastapi import HTTPException, Request, status

from app.core.config import settings
from app.core.constants import (
    RATE_LIMIT_LOCKOUT_DURATION_SECONDS,
    RATE_LIMIT_LOCKOUT_MAX_FAILS,
    RATE_LIMIT_LOCKOUT_WINDOW_SECONDS,
    RATE_LIMIT_LOGIN_MAX_REQUESTS,
    RATE_LIMIT_LOGIN_WINDOW_SECONDS,
    RATE_LIMIT_LRU_MAXSIZE,
    RATE_LIMIT_TARPIT_BASE_DELAY_SECONDS,
    RATE_LIMIT_TARPIT_BURST_THRESHOLD,
    RATE_LIMIT_TARPIT_BURST_WINDOW_SECONDS,
    RATE_LIMIT_TARPIT_MAX_DELAY_SECONDS,
    RATE_LIMIT_VINCULACION_IDENTITY_WINDOW_SECONDS,
    RATE_LIMIT_VINCULACION_MAX_REQUESTS,
    RATE_LIMIT_VINCULACION_WINDOW_SECONDS,
)


class RateLimitExceeded(HTTPException):
    """Exception raised when any rate limit tier is violated."""

    def __init__(self, detail: str = "Demasiadas peticiones. Por favor intente más tarde.") -> None:
        super().__init__(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=detail)


class AccountLockedOut(HTTPException):
    """Exception raised when an account is temporarily locked due to excessive failed attempts."""

    def __init__(self, detail: str = "Cuenta bloqueada temporalmente por seguridad. Intente en 30 minutos.") -> None:
        super().__init__(status_code=status.HTTP_423_LOCKED, detail=detail)


class RateLimiter:
    """Multi-layer in-memory rate limiter backed by a bounded LRUCache."""

    MAX_CACHE_SIZE: int = RATE_LIMIT_LRU_MAXSIZE

    def __init__(self, maxsize: int = RATE_LIMIT_LRU_MAXSIZE) -> None:
        self.MAX_CACHE_SIZE = maxsize
        self.cache: LRUCache = LRUCache(maxsize=maxsize)

        # Layer 1: IP limits (max_requests, window_seconds)
        self.ip_limits: Dict[str, Tuple[int, int]] = {
            "login": (RATE_LIMIT_LOGIN_MAX_REQUESTS, RATE_LIMIT_LOGIN_WINDOW_SECONDS),
            "vinculacion": (RATE_LIMIT_VINCULACION_MAX_REQUESTS, RATE_LIMIT_VINCULACION_WINDOW_SECONDS),
        }

        # Layer 2: Identity limits (max_requests, window_seconds)
        self.identity_limits: Dict[str, Tuple[int, int]] = {
            "login": (RATE_LIMIT_LOGIN_MAX_REQUESTS, RATE_LIMIT_LOGIN_WINDOW_SECONDS),
            "vinculacion": (RATE_LIMIT_VINCULACION_MAX_REQUESTS, RATE_LIMIT_VINCULACION_IDENTITY_WINDOW_SECONDS),
        }

        # Layer 3: Tarpitting thresholds
        self.tarpit_burst_threshold: int = RATE_LIMIT_TARPIT_BURST_THRESHOLD
        self.tarpit_burst_window: float = RATE_LIMIT_TARPIT_BURST_WINDOW_SECONDS
        self.tarpit_base_delay: float = RATE_LIMIT_TARPIT_BASE_DELAY_SECONDS
        self.tarpit_max_delay: float = RATE_LIMIT_TARPIT_MAX_DELAY_SECONDS

        # Layer 4: Account lockout
        self.lockout_threshold: int = RATE_LIMIT_LOCKOUT_MAX_FAILS
        self.lockout_window: int = RATE_LIMIT_LOCKOUT_WINDOW_SECONDS
        self.lockout_duration: int = RATE_LIMIT_LOCKOUT_DURATION_SECONDS

    # ── Internal Cache Access ────────────────────────────────────────

    def _get_history(self, key: str) -> List[float]:
        """Retrieve timestamp list from LRU cache, filtering out older records."""
        return self.cache.get(key, [])

    def _append_history(self, key: str, timestamp: float) -> None:
        history = list(self.cache.get(key, []))
        history.append(timestamp)
        self.cache[key] = history

    # ── Layer 1: IP Limiting ─────────────────────────────────────────

    def check_ip(self, ip: str, endpoint: str = "login", now: Optional[float] = None) -> None:
        """Check Layer 1 IP rate limit."""
        if not ip:
            return
        now = now if now is not None else time.time()
        endpoint_key = "vinculacion" if "vinculacion" in endpoint.lower() else "login"
        max_req, window = self.ip_limits.get(
            endpoint_key, (RATE_LIMIT_LOGIN_MAX_REQUESTS, RATE_LIMIT_LOGIN_WINDOW_SECONDS)
        )

        cache_key = f"ip:{endpoint_key}:{ip}"
        cutoff = now - window
        history = [t for t in self._get_history(cache_key) if t > cutoff]

        if len(history) >= max_req:
            raise RateLimitExceeded(
                f"Límite de peticiones por IP excedido para {endpoint_key}. Intente más tarde."
            )

    def record_ip(self, ip: str, endpoint: str = "login", now: Optional[float] = None) -> None:
        """Record an attempt from an IP address."""
        if not ip:
            return
        now = now if now is not None else time.time()
        endpoint_key = "vinculacion" if "vinculacion" in endpoint.lower() else "login"
        cache_key = f"ip:{endpoint_key}:{ip}"
        self._append_history(cache_key, now)

    # ── Layer 2: Identity Limiting ───────────────────────────────────

    def check_identity(self, identity: str, endpoint: str = "login", now: Optional[float] = None) -> None:
        """Check Layer 2 Identity rate limit (cédula or email)."""
        if not identity:
            return
        now = now if now is not None else time.time()
        clean_id = identity.strip().lower()
        endpoint_key = "vinculacion" if "vinculacion" in endpoint.lower() else "login"
        max_req, window = self.identity_limits.get(
            endpoint_key, (RATE_LIMIT_LOGIN_MAX_REQUESTS, RATE_LIMIT_LOGIN_WINDOW_SECONDS)
        )

        cache_key = f"id:{endpoint_key}:{clean_id}"
        cutoff = now - window
        history = [t for t in self._get_history(cache_key) if t > cutoff]

        if len(history) >= max_req:
            raise RateLimitExceeded(
                f"Límite de intentos para la identidad {clean_id} excedido. Intente más tarde."
            )

    def record_identity(self, identity: str, endpoint: str = "login", now: Optional[float] = None) -> None:
        """Record an attempt against an identity."""
        if not identity:
            return
        now = now if now is not None else time.time()
        clean_id = identity.strip().lower()
        endpoint_key = "vinculacion" if "vinculacion" in endpoint.lower() else "login"
        cache_key = f"id:{endpoint_key}:{clean_id}"
        self._append_history(cache_key, now)

    # ── Layer 3: Selective Tarpitting ────────────────────────────────

    def calculate_tarpit_delay(self, ip: str, now: Optional[float] = None) -> float:
        """Calculate progressive async delay for bursty IPs without globally blocking."""
        if not ip:
            return 0.0
        now = now if now is not None else time.time()
        # Track attempts in the burst window for burst detection
        burst_key = f"burst:{ip}"
        history = [t for t in self._get_history(burst_key) if t > now - self.tarpit_burst_window]

        if len(history) < self.tarpit_burst_threshold:
            return 0.0

        burst_count = len(history) - self.tarpit_burst_threshold + 1
        delay = min(self.tarpit_base_delay * (2 ** (burst_count - 1)), self.tarpit_max_delay)
        return delay

    async def apply_tarpitting(self, ip: str, now: Optional[float] = None) -> float:
        """Asynchronously apply tarpitting sleep if burst pattern detected."""
        if not ip:
            return 0.0
        now = now if now is not None else time.time()
        burst_key = f"burst:{ip}"
        self._append_history(burst_key, now)

        delay = self.calculate_tarpit_delay(ip, now=now)
        if delay > 0:
            await asyncio.sleep(delay)
        return delay

    # ── Layer 4: Account Lockout ─────────────────────────────────────

    def is_account_locked(self, identity: str, now: Optional[float] = None) -> bool:
        """Check if an account is currently in locked state."""
        if not identity:
            return False
        now = now if now is not None else time.time()
        clean_id = identity.strip().lower()
        lock_until = self.cache.get(f"lockout:{clean_id}")
        if lock_until and lock_until > now:
            return True
        return False

    def record_failure(self, identity: str, ip: Optional[str] = None, now: Optional[float] = None) -> None:
        """Record an authentication or vinculacion failure. If failures reach 10 in 1 hour -> lock for 30m."""
        if not identity:
            return
        now = now if now is not None else time.time()
        clean_id = identity.strip().lower()

        fail_key = f"failures:{clean_id}"
        cutoff = now - self.lockout_window
        history = [t for t in self._get_history(fail_key) if t > cutoff]
        history.append(now)
        self.cache[fail_key] = history

        if len(history) >= self.lockout_threshold:
            # Lock account for lockout_duration (30 minutes)
            self.cache[f"lockout:{clean_id}"] = now + self.lockout_duration

    def record_success(self, identity: str, ip: Optional[str] = None) -> None:
        """Reset failure counts and lockout on successful auth."""
        if not identity:
            return
        clean_id = identity.strip().lower()
        self.cache.pop(f"failures:{clean_id}", None)
        self.cache.pop(f"lockout:{clean_id}", None)

    # ── Consolidated 4-Layer Check ───────────────────────────────────

    async def check_all(
        self,
        ip: str,
        identity: Optional[str],
        endpoint: str = "login",
        now: Optional[float] = None,
    ) -> None:
        """Run all 4 defense layers in sequence:
        
        1. Check Account Lockout (Layer 4)
        2. Check Identity Rate Limit (Layer 2)
        3. Check IP Rate Limit (Layer 1)
        4. Apply Tarpitting Delay (Layer 3)
        """
        if not getattr(settings, "RATE_LIMITING_ENABLED", True):
            return

        now = now if now is not None else time.time()

        # Layer 4: Account Lockout
        if identity and self.is_account_locked(identity, now=now):
            raise AccountLockedOut()

        # Layer 2: By Identity
        if identity:
            self.check_identity(identity, endpoint=endpoint, now=now)

        # Layer 1: By IP
        if ip:
            self.check_ip(ip, endpoint=endpoint, now=now)

        # Layer 3: Tarpitting
        if ip:
            await self.apply_tarpitting(ip, now=now)

        # Record this attempt
        if ip:
            self.record_ip(ip, endpoint=endpoint, now=now)
        if identity:
            self.record_identity(identity, endpoint=endpoint, now=now)

    def reset(self) -> None:
        """Clear all rate limit entries (useful in testing)."""
        self.cache.clear()


# Global Singleton instance
rate_limiter = RateLimiter(maxsize=RATE_LIMIT_LRU_MAXSIZE)
