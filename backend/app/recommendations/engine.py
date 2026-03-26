"""
Vibeslol Recommendation Engine V1

Scoring approach:
- Popularity: weighted sum of likes, loops, comments, shares
- Collaborative filtering: users who liked X also liked Y
- Recency bias: newer videos get a boost (exponential decay)
- Anti-repetition: exclude videos the user has already watched
- Diversity: mix high-score videos with random discovery
"""

import math
import random
from datetime import datetime, timezone
from typing import List, Optional, Tuple

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.like import Like
from app.models.video import Video
from app.models.video_view import VideoView


# Scoring weights
WEIGHT_LIKES = 1.0
WEIGHT_LOOPS = 2.0  # loops are the #1 engagement signal
WEIGHT_COMMENTS = 1.5
WEIGHT_SHARES = 3.0  # shares indicate high-quality content

# Recency: half-life in hours (videos lose half their recency boost every N hours)
RECENCY_HALF_LIFE_HOURS = 48.0

# Feed composition
ALGO_FRACTION = 0.7  # 70% algorithm-ranked, 30% random discovery
MIN_DISCOVERY_SLOTS = 2


def _popularity_score(video: Video) -> float:
    """Raw popularity score from engagement counts."""
    return (
        WEIGHT_LIKES * video.like_count
        + WEIGHT_LOOPS * video.loop_count
        + WEIGHT_COMMENTS * video.comment_count
        + WEIGHT_SHARES * video.share_count
    )


def _recency_boost(created_at: datetime) -> float:
    """Exponential decay boost for newer videos."""
    now = datetime.now(timezone.utc)
    age_hours = (now - created_at.replace(tzinfo=timezone.utc if created_at.tzinfo is None else created_at.tzinfo)).total_seconds() / 3600.0
    if age_hours < 0:
        age_hours = 0
    return math.exp(-0.693 * age_hours / RECENCY_HALF_LIFE_HOURS)


async def get_watched_video_ids(db: AsyncSession, user_id: str) -> set:
    """Get set of video IDs the user has already watched."""
    result = await db.execute(
        select(VideoView.video_id).where(VideoView.user_id == user_id).distinct()
    )
    return {row[0] for row in result.all()}


async def get_collaborative_scores(
    db: AsyncSession, user_id: str
) -> dict:
    """
    Simple collaborative filtering: find videos liked by users who liked
    the same videos as the current user.

    Returns dict of video_id -> collaborative score (higher = more recommended).
    """
    # Step 1: Get videos the current user liked
    user_likes_result = await db.execute(
        select(Like.video_id).where(Like.user_id == user_id)
    )
    user_liked_video_ids = {row[0] for row in user_likes_result.all()}

    if not user_liked_video_ids:
        return {}

    # Step 2: Find other users who liked the same videos (similar taste)
    similar_users_result = await db.execute(
        select(Like.user_id)
        .where(Like.video_id.in_(user_liked_video_ids))
        .where(Like.user_id != user_id)
        .group_by(Like.user_id)
        .having(func.count() >= 1)
        .limit(50)  # cap for performance
    )
    similar_user_ids = [row[0] for row in similar_users_result.all()]

    if not similar_user_ids:
        return {}

    # Step 3: Get videos those similar users liked (that current user hasn't)
    collab_result = await db.execute(
        select(Like.video_id, func.count().label("score"))
        .where(Like.user_id.in_(similar_user_ids))
        .where(Like.video_id.notin_(user_liked_video_ids))
        .group_by(Like.video_id)
    )

    return {row[0]: row[1] for row in collab_result.all()}


async def get_recommended_feed(
    db: AsyncSession,
    user_id: Optional[str] = None,
    page: int = 0,
    limit: int = 20,
    blocked_author_ids: Optional[List[str]] = None,
) -> List[Video]:
    """
    V1 recommendation engine.

    For anonymous/no-user: popularity + recency scoring.
    For known users: adds collaborative filtering + anti-repetition.
    """
    # Fetch a larger candidate pool to score and rank
    pool_size = limit * 5
    query = select(Video)
    if blocked_author_ids:
        query = query.where(Video.author_id.notin_(blocked_author_ids))
    query = query.order_by(Video.created_at.desc()).limit(pool_size)
    result = await db.execute(query)
    all_videos = list(result.scalars().all())

    if not all_videos:
        return []

    # Get user-specific signals
    watched_ids: set = set()
    collab_scores: dict = {}

    if user_id:
        watched_ids = await get_watched_video_ids(db, user_id)
        collab_scores = await get_collaborative_scores(db, user_id)

    # Score each video
    scored: List[Tuple[float, Video]] = []
    unseen: List[Video] = []

    for video in all_videos:
        # Skip videos user has already seen (for anti-repetition)
        is_watched = video.id in watched_ids

        # Base popularity
        pop = _popularity_score(video)

        # Recency boost
        recency = _recency_boost(video.created_at)

        # Collaborative filtering boost
        collab = collab_scores.get(video.id, 0) * 5.0  # scale up collab signal

        # Combined score
        score = (pop + collab) * (1.0 + recency)

        if not is_watched:
            unseen.append(video)

        scored.append((score, video))

    # Sort by score descending
    scored.sort(key=lambda x: x[0], reverse=True)

    # Build the feed: mix algorithm picks with random discovery
    algo_count = max(limit - MIN_DISCOVERY_SLOTS, int(limit * ALGO_FRACTION))
    discovery_count = limit - algo_count

    # Algorithm picks: top-scored unseen videos first, then seen ones as fallback
    unseen_ids = {v.id for v in unseen}
    algo_pool = [v for s, v in scored if v.id in unseen_ids]
    fallback_pool = [v for s, v in scored if v.id not in unseen_ids]

    algo_picks = algo_pool[:algo_count]
    if len(algo_picks) < algo_count:
        algo_picks.extend(fallback_pool[: algo_count - len(algo_picks)])

    # Discovery picks: random unseen videos not already in algo picks
    algo_pick_ids = {v.id for v in algo_picks}
    discovery_candidates = [v for v in unseen if v.id not in algo_pick_ids]
    if len(discovery_candidates) < discovery_count:
        # Fall back to any video not in algo picks
        discovery_candidates = [v for v in all_videos if v.id not in algo_pick_ids]

    random.shuffle(discovery_candidates)
    discovery_picks = discovery_candidates[:discovery_count]

    # Combine and shuffle discovery slots into the feed
    feed = algo_picks + discovery_picks

    # Paginate from the combined feed
    start = page * limit
    end = start + limit
    paginated = feed[start:end]

    # If we don't have enough for this page, just return what we have
    if not paginated and page > 0:
        return []

    return paginated
