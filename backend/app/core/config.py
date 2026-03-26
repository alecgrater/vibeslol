from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./vibeslol.db"

    # JWT
    SECRET_KEY: str = "dev-secret-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Cloudflare R2
    R2_ACCESS_KEY_ID: str = ""
    R2_SECRET_ACCESS_KEY: str = ""
    R2_BUCKET_NAME: str = ""
    R2_ENDPOINT_URL: str = ""
    R2_PUBLIC_URL: str = ""

    # Cloudflare Stream (legacy)
    CF_ACCOUNT_ID: str = ""
    CF_API_TOKEN: str = ""

    # Redis
    REDIS_URL: str = ""

    # CORS
    CORS_ORIGINS: list[str] = ["*"]

    # App
    APP_NAME: str = "Vibeslol"
    VIDEO_DURATION_SECONDS: int = 6
    ENVIRONMENT: str = "development"

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
