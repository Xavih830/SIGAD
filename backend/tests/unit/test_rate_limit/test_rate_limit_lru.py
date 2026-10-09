"""Acotamiento estricto de memoria en caché LRU a <= 10.000 entradas (~2 MB)."""

import sys
from cachetools import LRUCache

from app.core.rate_limit import RateLimiter, rate_limiter


def test_rate_limiter_uses_bounded_lru_cache():
    """Verify that global rate limiter uses LRUCache with maxsize <= 10,000."""
    assert isinstance(rate_limiter.cache, LRUCache), "rate_limiter.cache must be an LRUCache"
    assert rate_limiter.cache.maxsize == 10000, "rate_limiter cache maxsize must be exactly 10,000"


def test_rate_limiter_lru_eviction_and_max_size():
    """Verify that adding entries beyond maxsize strictly bounds cache size and evicts oldest items."""
    test_max = 50
    limiter = RateLimiter(maxsize=test_max)

    for i in range(test_max + 25):
        limiter.record_ip(f"192.168.1.{i}", endpoint="login")

    assert len(limiter.cache) == test_max

    assert "ip:login:192.168.1.0" not in limiter.cache
    assert "ip:login:192.168.1.24" not in limiter.cache

    assert f"ip:login:192.168.1.{test_max + 24}" in limiter.cache


def test_rate_limiter_memory_footprint_under_2mb():
    """Verify that 10,000 typical rate limit entries in LRU consume <= 2 MB."""
    limiter = RateLimiter(maxsize=10000)

    for i in range(10000):
        limiter.cache[f"ip:login:10.0.{i // 256}.{i % 256}"] = [1700000000.0 + i]

    assert len(limiter.cache) == 10000

    total_bytes = sys.getsizeof(limiter.cache)
    for k, v in limiter.cache.items():
        total_bytes += sys.getsizeof(k) + sys.getsizeof(v)

    size_mb = total_bytes / (1024 * 1024)
    assert size_mb <= 2.0, f"Cache size {size_mb:.2f} MB exceeds 2 MB RAM limit"
