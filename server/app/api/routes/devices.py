from fastapi import APIRouter

from app.schemas.sensor_reading import DeviceSummary
from app.services.reading_service import reading_service


router = APIRouter(prefix="/api/devices", tags=["devices"])


@router.get("", response_model=list[DeviceSummary])
def get_devices() -> list[DeviceSummary]:
    return reading_service.devices()
