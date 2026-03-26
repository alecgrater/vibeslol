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
from app.models.comment import Comment
from app.models.follow import Follow
from app.models.like import Like
from app.models.user import User
from app.models.video import Video
from app.models.video_view import VideoView
from app.recommendations.engine import get_recommended_feed
from app.schemas import (
    CommentCreateRequest,
    CommentOut,
    CreateAnonymousUserRequest,
    FollowOut,
    LikeOut,
    UserOut,
    VideoOut,
    VideoUploadOut,
    WatchEventOut,
    WatchEventRequest,
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
    user_id: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    # V1: Algorithm-powered feed with popularity + collaborative filtering + recency
    videos = await get_recommended_feed(db, user_id=user_id, page=page, limit=limit)
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


# ---------- Comments ----------

@router.get("/videos/{video_id}/comments", response_model=List[CommentOut])
async def get_comments(
    video_id: str,
    db: AsyncSession = Depends(get_db),
):
    video = await db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    result = await db.execute(
        select(Comment)
        .where(Comment.video_id == video_id)
        .order_by(Comment.created_at.desc())
    )
    comments = result.scalars().all()
    out = []
    for c in comments:
        user = await db.get(User, c.user_id)
        out.append(CommentOut(
            id=c.id,
            user_id=c.user_id,
            username=user.username if user else "unknown",
            text=c.text,
            created_at=c.created_at,
        ))
    return out


@router.post("/videos/{video_id}/comments", response_model=CommentOut, status_code=201)
async def create_comment(
    video_id: str,
    body: CommentCreateRequest,
    db: AsyncSession = Depends(get_db),
):
    video = await db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    user = await db.get(User, body.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    comment = Comment(user_id=body.user_id, video_id=video_id, text=body.text)
    db.add(comment)
    video.comment_count += 1
    await db.commit()
    await db.refresh(comment)

    return CommentOut(
        id=comment.id,
        user_id=comment.user_id,
        username=user.username,
        text=comment.text,
        created_at=comment.created_at,
    )


def _video_out(video: Video, username: str) -> VideoOut:
    return VideoOut(
        id=video.id,
        author_id=video.author_id,
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


# ---------- Follow ----------

@router.post("/users/{user_id}/follow", response_model=FollowOut)
async def toggle_follow(
    user_id: str,
    follower_id: str = Form(...),
    db: AsyncSession = Depends(get_db),
):
    if user_id == follower_id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")

    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    follower = await db.get(User, follower_id)
    if not follower:
        raise HTTPException(status_code=404, detail="Follower not found")

    existing = await db.execute(
        select(Follow).where(Follow.follower_id == follower_id, Follow.following_id == user_id)
    )
    existing_follow = existing.scalar_one_or_none()

    if existing_follow:
        await db.delete(existing_follow)
        await db.commit()
    else:
        follow = Follow(follower_id=follower_id, following_id=user_id)
        db.add(follow)
        await db.commit()

    follower_count = await db.scalar(
        select(func.count()).where(Follow.following_id == user_id)
    )
    return FollowOut(following=existing_follow is None, follower_count=follower_count or 0)


@router.get("/users/{user_id}/videos", response_model=List[VideoOut])
async def get_user_videos(
    user_id: str,
    page: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    result = await db.execute(
        select(Video)
        .where(Video.author_id == user_id)
        .order_by(Video.created_at.desc())
        .offset(page * limit)
        .limit(limit)
    )
    videos = result.scalars().all()
    return [_video_out(v, user.username) for v in videos]


@router.get("/videos/following-feed", response_model=List[VideoOut])
async def get_following_feed(
    user_id: str,
    page: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
):
    following_result = await db.execute(
        select(Follow.following_id).where(Follow.follower_id == user_id)
    )
    following_ids = [row[0] for row in following_result.all()]

    if not following_ids:
        return []

    result = await db.execute(
        select(Video)
        .where(Video.author_id.in_(following_ids))
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


@router.get("/users/{user_id}/is-following")
async def check_is_following(
    user_id: str,
    follower_id: str,
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(Follow).where(Follow.follower_id == follower_id, Follow.following_id == user_id)
    )
    return {"following": existing.scalar_one_or_none() is not None}


# ---------- Analytics ----------

@router.post("/analytics/watch", response_model=WatchEventOut)
async def track_watch_event(
    body: WatchEventRequest,
    db: AsyncSession = Depends(get_db),
):
    # Log the watch event
    view = VideoView(
        user_id=body.user_id,
        video_id=body.video_id,
        watch_duration_ms=body.watch_duration_ms,
        loop_count=body.loop_count,
        skipped=body.skipped,
        watch_percentage=body.watch_percentage,
    )
    db.add(view)

    # Update the video's aggregate loop count
    if body.loop_count > 0:
        video = await db.get(Video, body.video_id)
        if video:
            video.loop_count += body.loop_count

    await db.commit()
    return WatchEventOut(status="ok")
