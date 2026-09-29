import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import verify_admin_key
from app.db import get_db
from app.models import DeviceModel
from app.routers.readings import now_local
from app.schemas import DeviceAdminOut, DeviceOut, DeviceRegisterIn


router = APIRouter(prefix="/api/devices", tags=["devices"])
admin_router = APIRouter(prefix="/api/admin/devices", tags=["admin"])


def public_device(device: DeviceModel) -> DeviceOut:
    return DeviceOut(
        device_id=device.device_id,
        name=device.name,
        created_at=device.created_at,
        last_seen=device.last_seen,
    )


def admin_device(device: DeviceModel) -> DeviceAdminOut:
    return DeviceAdminOut(**public_device(device).model_dump(), device_key=device.device_key)


@router.get("", response_model=list[DeviceOut])
def list_devices(db: Session = Depends(get_db)) -> list[DeviceOut]:
    return [public_device(device) for device in db.scalars(select(DeviceModel).order_by(DeviceModel.device_id)).all()]


@admin_router.post("", response_model=DeviceAdminOut, status_code=status.HTTP_201_CREATED)
def register_device(
    payload: DeviceRegisterIn,
    _: None = Depends(verify_admin_key),
    db: Session = Depends(get_db),
) -> DeviceAdminOut:
    if db.get(DeviceModel, payload.device_id) is not None:
        raise HTTPException(status_code=409, detail="Device is already registered")
    device = DeviceModel(
        device_id=payload.device_id,
        name=payload.name,
        device_key=payload.device_key or secrets.token_urlsafe(24),
        created_at=now_local(),
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    return admin_device(device)


@admin_router.get("", response_model=list[DeviceAdminOut])
def list_devices_with_keys(
    _: None = Depends(verify_admin_key), db: Session = Depends(get_db)
) -> list[DeviceAdminOut]:
    return [admin_device(device) for device in db.scalars(select(DeviceModel).order_by(DeviceModel.device_id)).all()]