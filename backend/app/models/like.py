from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Like(Base):
    __tablename__ = "likes"
    __table_args__ = (UniqueConstraint("user_id", "video_id", name="uq_user_video_like"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    video_id: Mapped[str] = mapped_column(String(36), ForeignKey("videos.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    user: Mapped["User"] = relationship("User", back_populates="likes")  # noqa: F821
    video: Mapped["Video"] = relationship("Video", back_populates="likes")  # noqa: F821
