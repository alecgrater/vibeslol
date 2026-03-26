import ssl
from urllib.parse import parse_qs, urlencode, urlparse, urlunparse

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings


def _clean_asyncpg_url(url: str) -> tuple[str, dict]:
    """Strip query params that asyncpg doesn't understand (sslmode, channel_binding)
    and convert them to connect_args."""
    parsed = urlparse(url)
    params = parse_qs(parsed.query)

    connect_args: dict = {}
    needs_ssl = params.pop("sslmode", [None])[0] in ("require", "verify-ca", "verify-full")
    params.pop("channel_binding", None)

    if needs_ssl:
        connect_args["ssl"] = ssl.create_default_context()

    clean_query = urlencode({k: v[0] for k, v in params.items()})
    clean_url = urlunparse(parsed._replace(query=clean_query))
    return clean_url, connect_args


connect_args: dict = {}
pool_kwargs: dict = {}
db_url = settings.DATABASE_URL

if db_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
elif db_url.startswith("postgresql"):
    # Ensure async driver prefix
    if "asyncpg" not in db_url:
        db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
    db_url, connect_args = _clean_asyncpg_url(db_url)
    pool_kwargs = {"pool_size": 10, "max_overflow": 20}
else:
    pool_kwargs = {"pool_size": 10, "max_overflow": 20}

engine = create_async_engine(
    db_url,
    echo=False,
    connect_args=connect_args,
    **pool_kwargs,
)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db():
    async with async_session() as session:
        yield session
