from datetime import datetime
from typing import Optional

from pydantic import BaseModel


# --- User ---

class UserOut(BaseModel):
    id: str
    username: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    follower_count: int = 0
    following_count: int = 0
    video_count: int = 0
    is_anonymous: bool = True
    created_at: datetime

    model_config = {"from_attributes": True}


class CreateAnonymousUserRequest(BaseModel):
    device_token: Optional[str] = None


# --- Video ---

class VideoOut(BaseModel):
    id: str
    author_id: str
    username: str
    caption: Optional[str] = None
    video_url: str
    thumbnail_url: Optional[str] = None
    like_count: int = 0
    comment_count: int = 0
    share_count: int = 0
    loop_count: int = 0
    created_at: datetime

    model_config = {"from_attributes": True}


class VideoUploadOut(BaseModel):
    id: str
    video_url: str
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Comment ---

class CommentOut(BaseModel):
    id: int
    user_id: str
    username: str
    text: str
    created_at: datetime

    model_config = {"from_attributes": True}


class CommentCreateRequest(BaseModel):
    user_id: str
    text: str


# --- Like ---

class LikeOut(BaseModel):
    liked: bool
    like_count: int


# --- Follow ---

class FollowOut(BaseModel):
    following: bool
    follower_count: int


# --- Analytics ---

class WatchEventRequest(BaseModel):
    user_id: str
    video_id: str
    watch_duration_ms: int
    loop_count: int = 0
    skipped: bool = False
    watch_percentage: float = 0.0


class WatchEventOut(BaseModel):
    status: str = "ok"


# --- Report ---

class ReportCreateRequest(BaseModel):
    reporter_id: str
    reason: str
    details: Optional[str] = None


class ReportOut(BaseModel):
    id: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Block ---

class BlockToggleRequest(BaseModel):
    blocker_id: str


class BlockOut(BaseModel):
    blocked: bool


# --- Analytics ---

class AnalyticsOverview(BaseModel):
    total_users: int
    total_videos: int
    total_views: int
    total_likes: int
    avg_loops_per_video: float
    avg_watch_percentage: float


class TrendingVideoOut(BaseModel):
    id: str
    author_id: str
    username: str
    caption: Optional[str] = None
    like_count: int
    comment_count: int
    loop_count: int
    view_count: int
    engagement_score: float
