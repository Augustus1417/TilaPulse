from fastapi import APIRouter, HTTPException, Query

from app.schemas.sensor_reading import SensorReading, SensorReadingCreate
from app.services.reading_service import reading_service


router = APIRouter(prefix="/api/readings", tags=["readings"])


@router.post("", response_model=SensorReading, status_code=201)
def create_reading(reading: SensorReadingCreate) -> SensorReading:
    return reading_service.add_reading(reading)


@router.get("/latest", response_model=SensorReading)
def get_latest_reading(device_id: str = Query(min_length=1)) -> SensorReading:
    reading = reading_service.latest(device_id)
    if reading is None:
        raise HTTPException(status_code=404, detail="No reading found for this device")
    return reading


@router.get("", response_model=list[SensorReading])
def get_readings(
    device_id: str | None = Query(default=None, min_length=1),
    limit: int = Query(default=100, ge=1, le=1000),
) -> list[SensorReading]:
    return reading_service.recent(device_id=device_id, limit=limit)
