import json
from datetime import timedelta

import redis.asyncio as aioredis

from app.core.config import settings

_redis: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis | None:
    """Lazy-init Redis connection. Returns None if REDIS_URL not configured."""
    global _redis
    if not settings.REDIS_URL:
        return None
    if _redis is None:
        _redis = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    return _redis


async def close_redis() -> None:
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None


async def cache_get(key: str) -> dict | list | None:
    """Get a cached value. Returns None on miss or if Redis is not configured."""
    r = await get_redis()
    if r is None:
        return None
    val = await r.get(key)
    if val is None:
        return None
    return json.loads(val)


async def cache_set(key: str, value: dict | list, ttl_seconds: int = 30) -> None:
    """Set a cached value with TTL. No-op if Redis is not configured."""
    r = await get_redis()
    if r is None:
        return
    await r.set(key, json.dumps(value, default=str), ex=ttl_seconds)


async def cache_delete(pattern: str) -> None:
    """Delete all keys matching a pattern. No-op if Redis is not configured."""
    r = await get_redis()
    if r is None:
        return
    keys = []
    async for key in r.scan_iter(match=pattern):
        keys.append(key)
    if keys:
        await r.delete(*keys)
