from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.auth_routes import router as auth_router
from app.api.routes import router, UPLOAD_DIR
from app.core.cache import close_redis
from app.core.config import settings
from app.core.database import engine
from app.models import Base
from app.services.storage import StorageService


@asynccontextmanager
async def lifespan(app: FastAPI):
    # In dev, auto-create tables for convenience. In prod, use `alembic upgrade head`.
    if not settings.is_production:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    # Initialize storage service
    app.state.storage = StorageService()
    yield
    # Cleanup
    await close_redis()


app = FastAPI(
    title="Vibeslol API",
    description="Backend API for Vibeslol — 6-second video platform",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(router)

# Only serve local uploads when R2 is not configured
if not settings.R2_ACCESS_KEY_ID:
    app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")


@app.get("/health")
async def health():
    return {"status": "vibing", "version": "1.0.0"}
