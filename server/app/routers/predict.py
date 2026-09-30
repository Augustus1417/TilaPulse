from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.core.security import verify_device_session
from app.models import DeviceModel, ReadingModel
from app.schemas import PredictionRequest, PredictionResponse


router = APIRouter(prefix="/api/predict", tags=["predictions"])


@router.post("", response_model=PredictionResponse)
def predict(
    payload: PredictionRequest,
    request: Request,
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> PredictionResponse:
    if payload.device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    if db.get(DeviceModel, payload.device_id) is None:
        raise HTTPException(status_code=404, detail="Device is not registered")
    records = db.scalars(
        select(ReadingModel).where(ReadingModel.device_id == payload.device_id).order_by(ReadingModel.id.asc())
    ).all()
    record_data = [
        {"device_id": reading.device_id, "temperature": reading.temperature, "ph": reading.ph, "dissolved_oxygen": reading.dissolved_oxygen}
        for reading in records
    ]
    if payload.readings:
        record_data.extend(reading.model_dump() for reading in payload.readings if reading.device_id == payload.device_id)
    if not record_data:
        raise HTTPException(status_code=404, detail="No readings found for device")
    try:
        result = request.app.state.prediction_service.predict(record_data)
    except (FileNotFoundError, RuntimeError) as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return PredictionResponse(device_id=payload.device_id, **result)