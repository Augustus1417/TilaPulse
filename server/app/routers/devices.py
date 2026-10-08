import secrets
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_device_key, verify_admin_key, verify_device_key, verify_device_session, verify_ingestion_device_key
from app.db import get_db
from app.models import DeviceModel, DeviceSessionModel
from app.routers.readings import now_local
from app.schemas import DeviceAdminOut, DeviceConnectIn, DeviceConnectOut, DeviceNameUpdate, DeviceOut, DeviceRegisterIn, DeviceRegistrationOut, ReadingStateUpdate


router = APIRouter(prefix="/api/devices", tags=["devices"])
admin_router = APIRouter(prefix="/api/admin/devices", tags=["admin"])
limiter = Limiter(key_func=get_remote_address)


def is_device_online(device: DeviceModel) -> bool:
    online = False
    if device.last_seen is not None:
        last_seen = datetime.strptime(device.last_seen, "%Y-%m-%d %H:%M:%S").replace(
            tzinfo=ZoneInfo(settings.timezone)
        )
        online = (datetime.now(ZoneInfo(settings.timezone)) - last_seen).total_seconds() < settings.online_threshold_seconds
    return online


def public_device(device: DeviceModel) -> DeviceOut:
    return DeviceOut(
        device_id=device.device_id,
        name=device.name,
        created_at=device.created_at,
        last_seen=device.last_seen,
        reading_enabled=device.reading_enabled,
        online=is_device_online(device),
    )


@router.get("", response_model=list[DeviceOut])
def list_devices(db: Session = Depends(get_db)) -> list[DeviceOut]:
    return [public_device(device) for device in db.scalars(select(DeviceModel).order_by(DeviceModel.device_id)).all()]


@admin_router.post("", response_model=DeviceRegistrationOut, status_code=status.HTTP_201_CREATED)
def register_device(
    payload: DeviceRegisterIn,
    _: None = Depends(verify_admin_key),
    db: Session = Depends(get_db),
) -> DeviceRegistrationOut:
    if db.get(DeviceModel, payload.device_id) is not None:
        raise HTTPException(status_code=409, detail="Device is already registered")
    raw_key = payload.device_key or secrets.token_urlsafe(24)
    device = DeviceModel(
        device_id=payload.device_id,
        name=payload.name,
        device_key_hash=hash_device_key(raw_key),
        created_at=now_local(),
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    return DeviceRegistrationOut(**public_device(device).model_dump(), device_key=raw_key)


@admin_router.get("", response_model=list[DeviceAdminOut])
def list_devices_with_keys(
    _: None = Depends(verify_admin_key), db: Session = Depends(get_db)
) -> list[DeviceAdminOut]:
    return [DeviceAdminOut(**public_device(device).model_dump()) for device in db.scalars(select(DeviceModel).order_by(DeviceModel.device_id)).all()]


@router.post("/connect", response_model=DeviceConnectOut)
@limiter.limit("5/minute")
def connect_device(
    request: Request, payload: DeviceConnectIn, db: Session = Depends(get_db)
) -> DeviceConnectOut:
    device = db.get(DeviceModel, payload.device_id)
    if device is None:
        raise HTTPException(status_code=401, detail="invalid device credentials")
    try:
        verify_device_key(payload.device_key, device.device_key_hash)
    except HTTPException as exc:
        raise HTTPException(status_code=401, detail="invalid device credentials") from exc
    token = secrets.token_urlsafe(32)
    db.add(DeviceSessionModel(token=token, device_id=device.device_id, created_at=now_local()))
    db.commit()
    return DeviceConnectOut(token=token)


@router.get("/{device_id}/command")
def get_device_command(
    device_id: str,
    x_device_key: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    device = db.get(DeviceModel, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device is not registered")
    verify_ingestion_device_key(device.device_key_hash, x_device_key)
    device.last_seen = now_local()
    db.commit()
    return {"reading_enabled": device.reading_enabled}


@router.patch("/{device_id}/reading-state", response_model=DeviceOut)
def update_reading_state(
    device_id: str,
    payload: ReadingStateUpdate,
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> DeviceOut:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    device = db.get(DeviceModel, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device is not registered")
    device.reading_enabled = payload.enabled
    db.commit()
    db.refresh(device)
    return public_device(device)


@router.patch("/{device_id}/name", response_model=DeviceOut)
def update_device_name(
    device_id: str,
    payload: DeviceNameUpdate,
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> DeviceOut:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    device = db.get(DeviceModel, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device is not registered")
    name = payload.name.strip()
    if not name or any(not character.isprintable() for character in name):
        raise HTTPException(status_code=422, detail="Device name must be 1-50 characters without control characters")
    if len(name) > 50:
        raise HTTPException(status_code=422, detail="Device name must be 1-50 characters without control characters")
    device.name = name
    db.commit()
    db.refresh(device)
    return public_device(device)


@router.delete("/disconnect", status_code=status.HTTP_204_NO_CONTENT)
def disconnect_device(
    request: Request, device_id: str = Depends(verify_device_session), db: Session = Depends(get_db)
) -> None:
    token = request.state.device_session_token
    db.execute(
        update(DeviceSessionModel)
        .where(DeviceSessionModel.token == token, DeviceSessionModel.device_id == device_id)
        .values(revoked=True)
    )
    db.commit()


@admin_router.post("/{device_id}/rotate-key", response_model=DeviceRegistrationOut)
def rotate_device_key(
    device_id: str, _: None = Depends(verify_admin_key), db: Session = Depends(get_db)
) -> DeviceRegistrationOut:
    device = db.get(DeviceModel, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device is not registered")
    raw_key = secrets.token_urlsafe(24)
    device.device_key_hash = hash_device_key(raw_key)
    db.execute(
        update(DeviceSessionModel)
        .where(DeviceSessionModel.device_id == device_id)
        .values(revoked=True)
    )
    db.commit()
    db.refresh(device)
    return DeviceRegistrationOut(**public_device(device).model_dump(), device_key=raw_key)