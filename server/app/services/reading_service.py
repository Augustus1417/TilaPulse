from collections import deque
from datetime import datetime, timezone
from threading import Lock

from app.schemas.sensor_reading import DeviceSummary, SensorReading, SensorReadingCreate


MAX_READINGS = 1000


class ReadingService:
    def __init__(self, max_readings: int = MAX_READINGS) -> None:
        self._readings: deque[SensorReading] = deque(maxlen=max_readings)
        self._latest_by_device: dict[str, SensorReading] = {}
        self._lock = Lock()

    def add_reading(
        self,
        reading: SensorReadingCreate,
        timestamp: datetime | None = None,
    ) -> SensorReading:
        timestamp = timestamp or datetime.now(timezone.utc)
        if timestamp.tzinfo is None:
            timestamp = timestamp.replace(tzinfo=timezone.utc)
        stored = SensorReading(**reading.model_dump(), timestamp=timestamp)
        with self._lock:
            self._readings.append(stored)
            self._latest_by_device[stored.device_id] = stored
        return stored

    def latest(self, device_id: str) -> SensorReading | None:
        with self._lock:
            return self._latest_by_device.get(device_id)

    def recent(self, device_id: str | None = None, limit: int = 100) -> list[SensorReading]:
        with self._lock:
            readings = list(reversed(self._readings))
        if device_id is not None:
            readings = [reading for reading in readings if reading.device_id == device_id]
        return readings[:limit]

    def devices(self) -> list[DeviceSummary]:
        with self._lock:
            return [
                DeviceSummary(device_id=device_id, last_seen=reading.timestamp)
                for device_id, reading in sorted(self._latest_by_device.items())
            ]

    def clear(self) -> None:
        with self._lock:
            self._readings.clear()
            self._latest_by_device.clear()


reading_service = ReadingService()
