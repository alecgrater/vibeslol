import asyncio
import os
import shutil
import uuid

import boto3
from botocore.config import Config as BotoConfig

from app.core.config import settings


class StorageService:
    """Handles video file storage — R2 in production, local filesystem in dev."""

    def __init__(self) -> None:
        self._s3_client = None
        if settings.R2_ACCESS_KEY_ID and settings.R2_BUCKET_NAME:
            self._s3_client = boto3.client(
                "s3",
                endpoint_url=settings.R2_ENDPOINT_URL,
                aws_access_key_id=settings.R2_ACCESS_KEY_ID,
                aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
                config=BotoConfig(signature_version="s3v4"),
            )

    @property
    def uses_r2(self) -> bool:
        return self._s3_client is not None

    async def upload_video(self, file_data: bytes, original_filename: str) -> str:
        """Upload video bytes and return the public URL."""
        vid = str(uuid.uuid4())
        ext = os.path.splitext(original_filename)[1] or ".mp4"
        filename = f"{vid}{ext}"

        if self._s3_client:
            return await self._upload_to_r2(filename, file_data)
        else:
            return self._upload_to_local(filename, file_data)

    async def _upload_to_r2(self, filename: str, file_data: bytes) -> str:
        """Upload to Cloudflare R2 via boto3 (sync, wrapped in thread)."""
        key = f"videos/{filename}"

        def _put():
            self._s3_client.put_object(
                Bucket=settings.R2_BUCKET_NAME,
                Key=key,
                Body=file_data,
                ContentType="video/mp4",
            )

        await asyncio.to_thread(_put)
        return f"{settings.R2_PUBLIC_URL}/{key}"

    def _upload_to_local(self, filename: str, file_data: bytes) -> str:
        """Save to local uploads/ directory."""
        upload_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads"
        )
        os.makedirs(upload_dir, exist_ok=True)
        filepath = os.path.join(upload_dir, filename)
        with open(filepath, "wb") as f:
            f.write(file_data)
        return f"/uploads/{filename}"
