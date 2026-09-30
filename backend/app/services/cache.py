"""Tiny in-memory cache so we don't hit outside APIs on every request."""
import asyncio
import time
from typing import Any, Awaitable, Callable
_store: dict[str, tuple[float, Any]] = {}
_locks: dict[str, asyncio.Lock] = {}
async def cached(key: str, ttl: float, fn: Callable[[], Awaitable[Any]]) -> Any:
    hit = _store.get(key)
    if hit and time.time() - hit[0] < ttl:
        return hit[1]
    lock = _locks.setdefault(key, asyncio.Lock())
    async with lock:
        hit = _store.get(key)
        if hit and time.time() - hit[0] < ttl:
            return hit[1]
        value = await fn()
        _store[key] = (time.time(), value)
        return value
def clear() -> None:
    _store.clear()
