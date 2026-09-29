from sqlalchemy import Float, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class DeviceModel(Base):
    __tablename__ = "devices"

    device_id: Mapped[str] = mapped_column(String(120), primary_key=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    device_key: Mapped[str] = mapped_column(String(200), nullable=False)
    created_at: Mapped[str] = mapped_column(String(19), nullable=False)
    last_seen: Mapped[str | None] = mapped_column(String(19), nullable=True)

    readings: Mapped[list["ReadingModel"]] = relationship(back_populates="device")


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