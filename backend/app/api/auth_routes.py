import random
import uuid

from fastapi import APIRouter, Depends, HTTPException
from jose import JWTError, jwt
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import (
    _decode_token,
    create_access_token,
    create_refresh_token,
    get_current_user,
)
from app.core.config import settings
from app.core.database import get_db
from app.models.user import User


router = APIRouter(prefix="/api/auth")


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    username: str


class AnonymousAuthRequest(BaseModel):
    device_token: str | None = None


class RefreshRequest(BaseModel):
    refresh_token: str


@router.post("/anonymous", response_model=TokenResponse)
async def create_anonymous_account(
    body: AnonymousAuthRequest | None = None,
    db: AsyncSession = Depends(get_db),
):
    """Create an anonymous account and return JWT tokens."""
    uid = str(uuid.uuid4())
    username = f"vibe_{random.randint(1000, 9999)}"
    user = User(
        id=uid,
        username=username,
        is_anonymous=True,
        device_token=body.device_token if body else None,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        user_id=user.id,
        username=user.username,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_tokens(
    body: RefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    """Exchange a refresh token for new access + refresh tokens."""
    user_id = _decode_token(body.refresh_token, expected_type="refresh")
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        user_id=user.id,
        username=user.username,
    )
