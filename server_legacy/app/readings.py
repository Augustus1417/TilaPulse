from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db import get_db
from app.models import DeviceModel, ReadingModel
from app.schemas import SensorReading, SensorReadingCreate


MAX_READINGS = 1000
PHILIPPINE_TIMEZONE = ZoneInfo("Asia/Manila")


router = APIRouter(prefix="/api/readings", tags=["readings"])

def _reading_response(reading: ReadingModel) -> SensorReading:
    return SensorReading.model_validate(reading, from_attributes=True)


@router.post("", response_model=SensorReading, status_code=201)
def create_reading(reading: SensorReadingCreate, x_device_key: str | None = Header(default=None, alias="X-Device-Key"), db: Session = Depends(get_db)) -> SensorReading:
    if not x_device_key or settings.device_keys.get(reading.device_id) != x_device_key:
        raise HTTPException(status_code=401, detail="Invalid device key")

    timestamp = datetime.now(PHILIPPINE_TIMEZONE).strftime("%Y-%m-%d %H:%M:%S")
    device = db.get(DeviceModel, reading.device_id)
    if device is None:
        device = DeviceModel(device_id=reading.device_id, created_at=timestamp)
        db.add(device)
    device.last_seen = timestamp
    stored = ReadingModel(**reading.model_dump(), timestamp=timestamp)
    db.add(stored)
    db.commit()
    db.refresh(stored)
    return _reading_response(stored)


@router.get("/latest", response_model=SensorReading)
def get_latest_reading(device_id: str = Query(..., min_length=1), db: Session = Depends(get_db)) -> SensorReading:
    reading = db.scalars(select(ReadingModel).where(ReadingModel.device_id == device_id).order_by(ReadingModel.id.desc()).limit(1)).first()
    if reading is None:
        raise HTTPException(status_code=404, detail="No readings found")
    return _reading_response(reading)


@router.get("", response_model=list[SensorReading])
def get_readings(device_id: str = Query(..., min_length=1), limit: int = Query(default=100, ge=1, le=MAX_READINGS), db: Session = Depends(get_db)) -> list[SensorReading]:
    readings = db.scalars(select(ReadingModel).where(ReadingModel.device_id == device_id).order_by(ReadingModel.id.desc()).limit(limit)).all()
    return [_reading_response(reading) for reading in readings]


@router.get("/{device_id}", response_model=list[SensorReading])
def get_device_readings(device_id: str, limit: int = Query(default=100, ge=1, le=MAX_READINGS), db: Session = Depends(get_db)) -> list[SensorReading]:
    return get_readings(device_id=device_id, limit=limit, db=db)


devices_router = APIRouter(prefix="/api/devices", tags=["devices"])


@devices_router.get("", response_model=list[dict[str, str | None]])
def get_devices(db: Session = Depends(get_db)) -> list[dict[str, str | None]]:
    return [{"device_id": device.device_id, "name": device.name, "last_seen": device.last_seen, "created_at": device.created_at} for device in db.scalars(select(DeviceModel).order_by(DeviceModel.device_id)).all()]