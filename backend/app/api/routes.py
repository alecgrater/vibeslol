import os
import random
import shutil
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import VIDEO_DURATION_SECONDS
from app.core.database import get_db
from app.models.follow import Follow
from app.models.like import Like
from app.models.user import User
from app.models.video import Video
from app.schemas import (
    CreateAnonymousUserRequest,
    LikeOut,
    UserOut,
    VideoOut,
    VideoUploadOut,
)

router = APIRouter(prefix="/api")

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)


# ---------- Users ----------

@router.post("/users/anonymous", response_model=UserOut)
async def create_anonymous_user(
    body: Optional[CreateAnonymousUserRequest] = None,
    db: AsyncSession = Depends(get_db),
):
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
    return _user_out(user)


@router.get("/users/{user_id}", response_model=UserOut)
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    follower_count = await db.scalar(
        select(func.count()).where(Follow.following_id == user_id)
    )
    following_count = await db.scalar(
        select(func.count()).where(Follow.follower_id == user_id)
    )
    video_count = await db.scalar(
        select(func.count()).where(Video.author_id == user_id)
    )
    return _user_out(user, follower_count or 0, following_count or 0, video_count or 0)


def _user_out(user: User, follower_count: int = 0, following_count: int = 0, video_count: int = 0) -> UserOut:
    return UserOut(
        id=user.id,
        username=user.username,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        bio=user.bio,
        follower_count=follower_count,
        following_count=following_count,
        video_count=video_count,
        is_anonymous=user.is_anonymous,
        created_at=user.created_at,
    )


# ---------- Videos ----------

@router.get("/videos/feed", response_model=List[VideoOut])
async def get_feed(
    page: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
):
    # V0: reverse-chronological with a sprinkle of random. Algorithm V1 comes later.
    result = await db.execute(
        select(Video)
        .order_by(Video.created_at.desc())
        .offset(page * limit)
        .limit(limit)
    )
    videos = result.scalars().all()
    out = []
    for v in videos:
        author = await db.get(User, v.author_id)
        out.append(_video_out(v, author.username if author else "unknown"))
    return out


@router.post("/videos", response_model=VideoUploadOut, status_code=201)
async def upload_video(
    file: UploadFile = File(...),
    caption: Optional[str] = Form(None),
    author_id: str = Form(...),
    db: AsyncSession = Depends(get_db),
):
    author = await db.get(User, author_id)
    if not author:
        raise HTTPException(status_code=404, detail="Author not found")

    vid = str(uuid.uuid4())
    ext = os.path.splitext(file.filename or "video.mp4")[1] or ".mp4"
    filename = f"{vid}{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as f:
        shutil.copyfileobj(file.file, f)

    video_url = f"/uploads/{filename}"
    video = Video(
        id=vid,
        author_id=author_id,
        caption=caption,
        video_url=video_url,
        duration_ms=VIDEO_DURATION_SECONDS * 1000,
    )
    db.add(video)
    await db.commit()
    await db.refresh(video)
    return VideoUploadOut(id=video.id, video_url=video.video_url, created_at=video.created_at)


# ---------- Likes ----------

@router.post("/videos/{video_id}/like", response_model=LikeOut)
async def toggle_like(
    video_id: str,
    user_id: str = Form(...),
    db: AsyncSession = Depends(get_db),
):
    video = await db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    existing = await db.execute(
        select(Like).where(Like.user_id == user_id, Like.video_id == video_id)
    )
    existing_like = existing.scalar_one_or_none()

    if existing_like:
        # Unlike
        await db.delete(existing_like)
        video.like_count = max(0, video.like_count - 1)
        await db.commit()
        return LikeOut(liked=False, like_count=video.like_count)
    else:
        # Like
        like = Like(user_id=user_id, video_id=video_id)
        db.add(like)
        video.like_count += 1
        await db.commit()
        return LikeOut(liked=True, like_count=video.like_count)


def _video_out(video: Video, username: str) -> VideoOut:
    return VideoOut(
        id=video.id,
        username=username,
        caption=video.caption,
        video_url=video.video_url,
        thumbnail_url=video.thumbnail_url,
        like_count=video.like_count,
        comment_count=video.comment_count,
        share_count=video.share_count,
        loop_count=video.loop_count,
        created_at=video.created_at,
    )
