from fastapi import APIRouter, Query

from app.schemas.sensor_reading import SensorReading
from app.services.mock_sensor import DEFAULT_DEVICE_ID, mock_sensor
from app.services.reading_service import reading_service


router = APIRouter(prefix="/api/mock", tags=["mock"])


@router.post("/generate", response_model=SensorReading, status_code=201)
def generate_reading(device_id: str = Query(default=DEFAULT_DEVICE_ID, min_length=1, max_length=100)) -> SensorReading:
    return reading_service.add_reading(mock_sensor.generate(device_id))


@router.post("/generate-batch", response_model=list[SensorReading], status_code=201)
def generate_batch(
    count: int = Query(default=100, ge=1, le=1000),
    device_id: str = Query(default=DEFAULT_DEVICE_ID, min_length=1, max_length=100),
) -> list[SensorReading]:
    return [
        reading_service.add_reading(reading, timestamp=timestamp)
        for reading, timestamp in mock_sensor.generate_batch(device_id, count)
    ]
