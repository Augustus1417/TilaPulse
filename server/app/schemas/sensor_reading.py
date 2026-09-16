from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field, field_serializer


class SensorReadingCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_id: str = Field(min_length=1, max_length=100)
    temperature: float = Field(ge=-10, le=60)
    ph: float = Field(ge=0, le=14)
    dissolved_oxygen: float = Field(ge=0)


class SensorReading(SensorReadingCreate):
    timestamp: datetime

    @field_serializer("timestamp")
    def serialize_timestamp(self, timestamp: datetime) -> str:
        return timestamp.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


class DeviceSummary(BaseModel):
    device_id: str
    last_seen: datetime
