import os
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File, Form
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_current_user, get_current_user_optional
from app.core.cache import cache_delete, cache_get, cache_set
from app.core.config import settings
from app.core.database import get_db
from app.models.block import Block
from app.models.comment import Comment
from app.models.follow import Follow
from app.models.like import Like
from app.models.report import Report
from app.models.user import User
from app.models.video import Video
from app.models.video_view import VideoView
from app.recommendations.engine import get_recommended_feed
from app.schemas import (
    AnalyticsOverview,
    BlockOut,
    CommentCreateRequest,
    CommentOut,
    FollowOut,
    LikeOut,
    ReportCreateRequest,
    ReportOut,
    TrendingVideoOut,
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

@router.get("/users/{user_id}", response_model=UserOut)
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)):
    # Check cache
    cache_key = f"user:{user_id}"
    cached = await cache_get(cache_key)
    if cached:
        return UserOut(**cached)

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
    result = _user_out(user, follower_count or 0, following_count or 0, video_count or 0)
    await cache_set(cache_key, result.model_dump(), ttl_seconds=60)
    return result


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

@router.get("/videos/feed", response_model=list[VideoOut])
async def get_feed(
    page: int = 0,
    limit: int = 20,
    current_user: User | None = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
):
    user_id = current_user.id if current_user else None
    blocked_ids: list = []
    if user_id:
        blocked_result = await db.execute(
            select(Block.blocked_id).where(Block.blocker_id == user_id)
        )
        blocked_ids = [row[0] for row in blocked_result.all()]

    videos = await get_recommended_feed(db, user_id=user_id, page=page, limit=limit, blocked_author_ids=blocked_ids)
    out = []
    for v in videos:
        author = await db.get(User, v.author_id)
        out.append(_video_out(v, author.username if author else "unknown"))
    return out


@router.post("/videos", response_model=VideoUploadOut, status_code=201)
async def upload_video(
    request: Request,
    file: UploadFile = File(...),
    caption: str | None = Form(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    storage = request.app.state.storage
    file_data = await file.read()
    video_url = await storage.upload_video(file_data, file.filename or "video.mp4")

    vid = str(uuid.uuid4())
    video = Video(
        id=vid,
        author_id=current_user.id,
        caption=caption,
        video_url=video_url,
        duration_ms=settings.VIDEO_DURATION_SECONDS * 1000,
    )
    db.add(video)
    await db.commit()
    await db.refresh(video)
    await cache_delete("feed:*")
    await cache_delete(f"user:{current_user.id}")
    return VideoUploadOut(id=video.id, video_url=video.video_url, created_at=video.created_at)


# ---------- Likes ----------

@router.post("/videos/{video_id}/like", response_model=LikeOut)
async def toggle_like(
    video_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    video = await db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    existing = await db.execute(
        select(Like).where(Like.user_id == current_user.id, Like.video_id == video_id)
    )
    existing_like = existing.scalar_one_or_none()

    if existing_like:
        await db.delete(existing_like)
        video.like_count = max(0, video.like_count - 1)
        await db.commit()
        return LikeOut(liked=False, like_count=video.like_count)
    else:
        like = Like(user_id=current_user.id, video_id=video_id)
        db.add(like)
        video.like_count += 1
        await db.commit()
        return LikeOut(liked=True, like_count=video.like_count)


# ---------- Comments ----------

@router.get("/videos/{video_id}/comments", response_model=list[CommentOut])
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
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    video = await db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    if current_user.is_anonymous:
        raise HTTPException(status_code=403, detail="Anonymous users cannot comment. Create an account first.")

    comment = Comment(user_id=current_user.id, video_id=video_id, text=body.text)
    db.add(comment)
    video.comment_count += 1
    await db.commit()
    await db.refresh(comment)

    return CommentOut(
        id=comment.id,
        user_id=comment.user_id,
        username=current_user.username,
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
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")

    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    existing = await db.execute(
        select(Follow).where(Follow.follower_id == current_user.id, Follow.following_id == user_id)
    )
    existing_follow = existing.scalar_one_or_none()

    if existing_follow:
        await db.delete(existing_follow)
        await db.commit()
    else:
        follow = Follow(follower_id=current_user.id, following_id=user_id)
        db.add(follow)
        await db.commit()

    follower_count = await db.scalar(
        select(func.count()).where(Follow.following_id == user_id)
    )
    # Invalidate user profile caches for both users
    await cache_delete(f"user:{user_id}")
    await cache_delete(f"user:{current_user.id}")
    return FollowOut(following=existing_follow is None, follower_count=follower_count or 0)


@router.get("/users/{user_id}/videos", response_model=list[VideoOut])
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


@router.get("/videos/following-feed", response_model=list[VideoOut])
async def get_following_feed(
    page: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    following_result = await db.execute(
        select(Follow.following_id).where(Follow.follower_id == current_user.id)
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
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(Follow).where(Follow.follower_id == current_user.id, Follow.following_id == user_id)
    )
    return {"following": existing.scalar_one_or_none() is not None}


# ---------- Analytics ----------

@router.post("/analytics/watch", response_model=WatchEventOut)
async def track_watch_event(
    body: WatchEventRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    view = VideoView(
        user_id=current_user.id,
        video_id=body.video_id,
        watch_duration_ms=body.watch_duration_ms,
        loop_count=body.loop_count,
        skipped=body.skipped,
        watch_percentage=body.watch_percentage,
    )
    db.add(view)

    if body.loop_count > 0:
        video = await db.get(Video, body.video_id)
        if video:
            video.loop_count += body.loop_count

    await db.commit()
    return WatchEventOut(status="ok")


# ---------- Report ----------

@router.post("/videos/{video_id}/report", response_model=ReportOut, status_code=201)
async def report_video(
    video_id: str,
    body: ReportCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    video = await db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    report = Report(
        reporter_id=current_user.id,
        video_id=video_id,
        reason=body.reason,
        details=body.details,
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)
    return ReportOut(id=report.id, status=report.status, created_at=report.created_at)


# ---------- Block ----------

@router.post("/users/{user_id}/block", response_model=BlockOut)
async def toggle_block(
    user_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot block yourself")

    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    existing = await db.execute(
        select(Block).where(Block.blocker_id == current_user.id, Block.blocked_id == user_id)
    )
    existing_block = existing.scalar_one_or_none()

    if existing_block:
        await db.delete(existing_block)
        await db.commit()
        return BlockOut(blocked=False)
    else:
        block = Block(blocker_id=current_user.id, blocked_id=user_id)
        db.add(block)
        existing_follow = await db.execute(
            select(Follow).where(Follow.follower_id == current_user.id, Follow.following_id == user_id)
        )
        follow = existing_follow.scalar_one_or_none()
        if follow:
            await db.delete(follow)
        await db.commit()
        return BlockOut(blocked=True)


# ---------- Analytics Dashboard ----------

@router.get("/analytics/overview", response_model=AnalyticsOverview)
async def analytics_overview(db: AsyncSession = Depends(get_db)):
    cached = await cache_get("analytics:overview")
    if cached:
        return AnalyticsOverview(**cached)

    total_users = await db.scalar(select(func.count()).select_from(User)) or 0
    total_videos = await db.scalar(select(func.count()).select_from(Video)) or 0
    total_views = await db.scalar(select(func.count()).select_from(VideoView)) or 0
    total_likes = await db.scalar(select(func.count()).select_from(Like)) or 0

    avg_loops = await db.scalar(
        select(func.avg(Video.loop_count)).where(Video.loop_count > 0)
    ) or 0.0

    avg_watch_pct = await db.scalar(
        select(func.avg(VideoView.watch_percentage))
    ) or 0.0

    result = AnalyticsOverview(
        total_users=total_users,
        total_videos=total_videos,
        total_views=total_views,
        total_likes=total_likes,
        avg_loops_per_video=round(float(avg_loops), 2),
        avg_watch_percentage=round(float(avg_watch_pct), 2),
    )
    await cache_set("analytics:overview", result.model_dump(), ttl_seconds=300)
    return result


@router.get("/analytics/trending", response_model=list[TrendingVideoOut])
async def analytics_trending(
    limit: int = 10,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Video).order_by(
            (Video.like_count + Video.loop_count * 2 + Video.comment_count).desc()
        ).limit(limit)
    )
    videos = result.scalars().all()

    out = []
    for v in videos:
        author = await db.get(User, v.author_id)
        view_count = await db.scalar(
            select(func.count()).where(VideoView.video_id == v.id)
        ) or 0
        score = float(v.like_count + v.loop_count * 2 + v.comment_count * 1.5 + v.share_count * 3)
        out.append(TrendingVideoOut(
            id=v.id,
            author_id=v.author_id,
            username=author.username if author else "unknown",
            caption=v.caption,
            like_count=v.like_count,
            comment_count=v.comment_count,
            loop_count=v.loop_count,
            view_count=view_count,
            engagement_score=round(score, 1),
        ))
    return out
