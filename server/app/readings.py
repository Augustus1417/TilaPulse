from collections import deque
from datetime import datetime
from threading import Lock
from zoneinfo import ZoneInfo

from fastapi import APIRouter, HTTPException, Query

from app.schemas import SensorReading, SensorReadingCreate


MAX_READINGS = 1000
PHILIPPINE_TIMEZONE = ZoneInfo("Asia/Manila")


class ReadingStore:
    """Bounded in-memory storage; readings disappear when the server restarts."""

    def __init__(self, max_readings: int = MAX_READINGS) -> None:
        self._readings: deque[SensorReading] = deque(maxlen=max_readings)
        self._lock = Lock()

    def add(self, reading: SensorReadingCreate) -> SensorReading:
        stored = SensorReading(
            **reading.model_dump(),
            timestamp=datetime.now(PHILIPPINE_TIMEZONE),
        )
        with self._lock:
            self._readings.append(stored)
        return stored

    def latest(self) -> SensorReading | None:
        with self._lock:
            return self._readings[-1] if self._readings else None

    def recent(self, limit: int = 100) -> list[SensorReading]:
        with self._lock:
            return list(reversed(self._readings))[:limit]

    def clear(self) -> None:
        with self._lock:
            self._readings.clear()


reading_store = ReadingStore()
router = APIRouter(prefix="/api/readings", tags=["readings"])


@router.post("", response_model=SensorReading, status_code=201)
def create_reading(reading: SensorReadingCreate) -> SensorReading:
    return reading_store.add(reading)


@router.get("/latest", response_model=SensorReading)
def get_latest_reading() -> SensorReading:
    reading = reading_store.latest()
    if reading is None:
        raise HTTPException(status_code=404, detail="No readings found")
    return reading


@router.get("", response_model=list[SensorReading])
def get_readings(limit: int = Query(default=100, ge=1, le=MAX_READINGS)) -> list[SensorReading]:
    return reading_store.recent(limit=limit)