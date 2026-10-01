from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import verify_device_session
from app.db import get_db
from app.models import AlertModel
from app.schemas import AlertOut


router = APIRouter(prefix="/api/devices", tags=["alerts"])


@router.get("/{device_id}/alerts", response_model=list[AlertOut])
def list_alerts(
    device_id: str,
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> list[AlertOut]:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    return db.scalars(
        select(AlertModel)
        .where(AlertModel.device_id == device_id)
        .order_by(AlertModel.id)
    ).all()


@router.delete("/{device_id}/alerts/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
def resolve_alert(
    device_id: str,
    alert_id: int,
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> None:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    alert = db.scalar(
        select(AlertModel).where(AlertModel.id == alert_id, AlertModel.device_id == device_id)
    )
    if alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")
    db.delete(alert)
    db.commit()