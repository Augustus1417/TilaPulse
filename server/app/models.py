from sqlalchemy import Boolean, Float, ForeignKey, Index, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class DeviceModel(Base):
    __tablename__ = "devices"

    device_id: Mapped[str] = mapped_column(String(120), primary_key=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    device_key_hash: Mapped[str] = mapped_column(String(200), nullable=False)
    created_at: Mapped[str] = mapped_column(String(19), nullable=False)
    last_seen: Mapped[str | None] = mapped_column(String(19), nullable=True)
    reading_enabled: Mapped[bool] = mapped_column(Boolean, default=True, server_default=text("true"), nullable=False)

    readings: Mapped[list["ReadingModel"]] = relationship(back_populates="device")
    sessions: Mapped[list["DeviceSessionModel"]] = relationship(back_populates="device")


class DeviceSessionModel(Base):
    __tablename__ = "device_sessions"

    token: Mapped[str] = mapped_column(String(200), primary_key=True)
    device_id: Mapped[str] = mapped_column(
        String(120), ForeignKey("devices.device_id"), index=True, nullable=False
    )
    created_at: Mapped[str] = mapped_column(String(19), nullable=False)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    device: Mapped[DeviceModel] = relationship(back_populates="sessions")


class ReadingModel(Base):
    __tablename__ = "readings"
    __table_args__ = (Index("ix_readings_device_timestamp", "device_id", "timestamp"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    device_id: Mapped[str] = mapped_column(
        String(120), ForeignKey("devices.device_id"), index=True, nullable=False
    )
    temperature: Mapped[float] = mapped_column(Float, nullable=False)
    ph: Mapped[float] = mapped_column(Float, nullable=False)
    dissolved_oxygen: Mapped[float] = mapped_column(Float, nullable=False)
    timestamp: Mapped[str] = mapped_column(String(19), nullable=False)

    device: Mapped[DeviceModel] = relationship(back_populates="readings")