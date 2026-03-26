import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    display_name: Mapped[str | None] = mapped_column(String(64), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    bio: Mapped[str | None] = mapped_column(String(256), nullable=True)
    is_anonymous: Mapped[bool] = mapped_column(Boolean, default=True)
    device_token: Mapped[str | None] = mapped_column(String(256), unique=True, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    videos: Mapped[list["Video"]] = relationship("Video", back_populates="author")  # noqa: F821
    likes: Mapped[list["Like"]] = relationship("Like", back_populates="user")  # noqa: F821
    comments: Mapped[list["Comment"]] = relationship("Comment", back_populates="user")  # noqa: F821
