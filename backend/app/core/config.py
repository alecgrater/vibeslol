import os

# Database
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "sqlite+aiosqlite:///./vibeslol.db",
)

# Cloudflare Stream
CF_ACCOUNT_ID = os.getenv("CF_ACCOUNT_ID", "")
CF_API_TOKEN = os.getenv("CF_API_TOKEN", "")

# App
APP_NAME = "Vibeslol"
VIDEO_DURATION_SECONDS = 6
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-in-production")
