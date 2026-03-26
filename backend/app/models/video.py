import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Video(Base):
    __tablename__ = "videos"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    author_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    caption: Mapped[str | None] = mapped_column(Text, nullable=True)
    video_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    thumbnail_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    duration_ms: Mapped[int] = mapped_column(Integer, default=6000)
    like_count: Mapped[int] = mapped_column(Integer, default=0)
    comment_count: Mapped[int] = mapped_column(Integer, default=0)
    share_count: Mapped[int] = mapped_column(Integer, default=0)
    loop_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    author: Mapped["User"] = relationship("User", back_populates="videos")  # noqa: F821
    likes: Mapped[list["Like"]] = relationship("Like", back_populates="video")  # noqa: F821
    comments: Mapped[list["Comment"]] = relationship("Comment", back_populates="video")  # noqa: F821
