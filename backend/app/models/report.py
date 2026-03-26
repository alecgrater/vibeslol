from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    reporter_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    video_id: Mapped[str] = mapped_column(String(36), ForeignKey("videos.id"), nullable=False)
    reason: Mapped[str] = mapped_column(String(64), nullable=False)
    details: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="pending")  # pending, reviewed, dismissed
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
