from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings

connect_args: dict = {}
pool_kwargs: dict = {}

if settings.DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
else:
    # PostgreSQL pool settings
    pool_kwargs = {"pool_size": 10, "max_overflow": 20}

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    connect_args=connect_args,
    **pool_kwargs,
)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db():
    async with async_session() as session:
        yield session
