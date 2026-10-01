from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import verify_ingestion_device_key, verify_device_session
from app.db import get_db
from app.models import DeviceModel, ReadingModel
from app.schemas import ReadingIn, ReadingOut


router = APIRouter(prefix="/api/readings", tags=["readings"])


def now_local() -> str:
    return datetime.now(ZoneInfo(settings.timezone)).strftime("%Y-%m-%d %H:%M:%S")


def to_reading_out(reading: ReadingModel) -> ReadingOut:
    return ReadingOut(
        device_id=reading.device_id,
        temperature=reading.temperature,
        ph=reading.ph,
        dissolved_oxygen=reading.dissolved_oxygen,
        timestamp=reading.timestamp,
    )


@router.post("", response_model=ReadingOut, status_code=status.HTTP_201_CREATED)
def create_reading(
    payload: ReadingIn,
    x_device_key: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> ReadingOut:
    device = db.get(DeviceModel, payload.device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device is not registered")
    verify_ingestion_device_key(device.device_key_hash, x_device_key)

    timestamp = now_local()
    device.last_seen = timestamp
    reading = ReadingModel(
        device_id=payload.device_id,
        temperature=payload.temperature,
        ph=payload.ph,
        dissolved_oxygen=payload.dissolved_oxygen,
        timestamp=timestamp,
    )
    db.add(reading)
    db.commit()
    db.refresh(reading)
    return to_reading_out(reading)


@router.get("", response_model=list[ReadingOut])
def list_readings(
    device_id: str = Query(min_length=1),
    limit: int = Query(default=100, ge=1, le=1000),
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> list[ReadingOut]:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    readings = db.scalars(
        select(ReadingModel)
        .where(ReadingModel.device_id == device_id)
        .order_by(ReadingModel.id.desc())
        .limit(limit)
    ).all()
    return [to_reading_out(reading) for reading in reversed(readings)]


@router.get("/latest", response_model=ReadingOut)
def latest_reading(
    device_id: str = Query(min_length=1),
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> ReadingOut:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    reading = db.scalar(
        select(ReadingModel)
        .where(ReadingModel.device_id == device_id)
        .order_by(ReadingModel.id.desc())
    )
    if reading is None:
        raise HTTPException(status_code=404, detail="No readings found for device")
    return to_reading_out(reading)