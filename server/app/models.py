from sqlalchemy import Boolean, Float, ForeignKey, Index, String, text, UniqueConstraint
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
    offline_notified: Mapped[bool] = mapped_column(Boolean, default=False, server_default=text("false"), nullable=False)

    readings: Mapped[list["ReadingModel"]] = relationship(back_populates="device")
    sessions: Mapped[list["DeviceSessionModel"]] = relationship(back_populates="device")
    alerts: Mapped[list["AlertModel"]] = relationship(back_populates="device")
    predictions: Mapped[list["PredictionModel"]] = relationship(back_populates="device")


class DeviceSessionModel(Base):
    __tablename__ = "device_sessions"

    token: Mapped[str] = mapped_column(String(200), primary_key=True)
    device_id: Mapped[str] = mapped_column(
        String(120), ForeignKey("devices.device_id"), index=True, nullable=False
    )
    created_at: Mapped[str] = mapped_column(String(19), nullable=False)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    device: Mapped[DeviceModel] = relationship(back_populates="sessions")


class PushTokenModel(Base):
    __tablename__ = "push_tokens"
    __table_args__ = (UniqueConstraint("fcm_token", "device_id", name="uq_push_tokens_token_device"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    device_id: Mapped[str] = mapped_column(String(120), ForeignKey("devices.device_id"), index=True, nullable=False)
    session_token: Mapped[str] = mapped_column(String(200), ForeignKey("device_sessions.token"), nullable=False)
    fcm_token: Mapped[str] = mapped_column(String(4096), nullable=False)
    created_at: Mapped[str] = mapped_column(String(19), nullable=False)


class NotificationLogModel(Base):
    __tablename__ = "notification_logs"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    device_id: Mapped[str] = mapped_column(String(120), ForeignKey("devices.device_id"), index=True, nullable=False)
    kind: Mapped[str] = mapped_column(String(30), nullable=False)
    key: Mapped[str] = mapped_column(String(200), nullable=False)
    sent_at: Mapped[str] = mapped_column(String(19), nullable=False)


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


class AlertModel(Base):
    __tablename__ = "alerts"
    __table_args__ = (
        Index("ix_alerts_device_parameter_unique", "device_id", "parameter", unique=True),
        {"sqlite_autoincrement": True},
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    device_id: Mapped[str] = mapped_column(
        String(120), ForeignKey("devices.device_id"), index=True, nullable=False
    )
    parameter: Mapped[str] = mapped_column(String(40), nullable=False)
    value: Mapped[float] = mapped_column(Float, nullable=False)
    threshold_breached: Mapped[str] = mapped_column(String(20), nullable=False)
    message: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[str] = mapped_column(String(19), nullable=False)

    device: Mapped[DeviceModel] = relationship(back_populates="alerts")


class PredictionModel(Base):
    __tablename__ = "predictions"
    __table_args__ = ({"sqlite_autoincrement": True},)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    device_id: Mapped[str] = mapped_column(
        String(120), ForeignKey("devices.device_id"), index=True, nullable=False
    )
    risk_score: Mapped[float] = mapped_column(Float, nullable=False)
    lstm_probability: Mapped[float] = mapped_column(Float, nullable=False)
    bocpd_change_point_probability: Mapped[float] = mapped_column(Float, nullable=False)
    risk_label: Mapped[str] = mapped_column(String(20), nullable=False)
    created_at: Mapped[str] = mapped_column(String(19), nullable=False)
    source: Mapped[str] = mapped_column(String(20), nullable=False, default="manual", server_default=text("'manual'"))

    device: Mapped[DeviceModel] = relationship(back_populates="predictions")