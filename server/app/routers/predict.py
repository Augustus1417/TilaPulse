from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import verify_device_session
from app.db import get_db
from app.models import DeviceModel, PredictionModel, ReadingModel
from app.routers.readings import now_local
from app.schemas import PredictionOut


router = APIRouter(prefix="/api/devices", tags=["predictions"])


def _risk_label(risk_score: float) -> str:
    if risk_score < 0.3:
        return "low"
    if risk_score < 0.6:
        return "moderate"
    return "high"


def _prediction_out(prediction: PredictionModel) -> PredictionOut:
    return PredictionOut(
        id=prediction.id,
        device_id=prediction.device_id,
        risk_score=prediction.risk_score,
        lstm_probability=prediction.lstm_probability,
        bocpd_change_point_probability=prediction.bocpd_change_point_probability,
        risk_label=prediction.risk_label,
        created_at=prediction.created_at,
    )


def _authorized_device(device_id: str, session_device_id: str, db: Session) -> None:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    if db.get(DeviceModel, device_id) is None:
        raise HTTPException(status_code=404, detail="Device is not registered")


@router.post("/{device_id}/predict", response_model=PredictionOut, status_code=status.HTTP_201_CREATED)
def create_prediction(
    device_id: str,
    request: Request,
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> PredictionOut:
    _authorized_device(device_id, session_device_id, db)
    records = db.scalars(
        select(ReadingModel)
        .where(ReadingModel.device_id == device_id)
        .order_by(ReadingModel.id.asc())
    ).all()
    if not records:
        raise HTTPException(status_code=404, detail="No readings found for device")
    record_data = [
        {
            "device_id": reading.device_id,
            "temperature": reading.temperature,
            "ph": reading.ph,
            "dissolved_oxygen": reading.dissolved_oxygen,
        }
        for reading in records
    ]
    try:
        result = request.app.state.prediction_service.predict(record_data)
    except (FileNotFoundError, RuntimeError) as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    risk_score = float(result["risk_score"])
    prediction = PredictionModel(
        device_id=device_id,
        risk_score=risk_score,
        lstm_probability=float(result["lstm_probability"]),
        bocpd_change_point_probability=float(result["bocpd_probability"]),
        risk_label=_risk_label(risk_score),
        created_at=now_local(),
    )
    db.add(prediction)
    db.commit()
    db.refresh(prediction)
    return _prediction_out(prediction)


@router.get("/{device_id}/risk/latest", response_model=PredictionOut)
def latest_prediction(
    device_id: str,
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> PredictionOut:
    _authorized_device(device_id, session_device_id, db)
    prediction = db.scalar(
        select(PredictionModel)
        .where(PredictionModel.device_id == device_id)
        .order_by(PredictionModel.id.desc())
    )
    if prediction is None:
        raise HTTPException(status_code=404, detail="No risk assessment found for device")
    return _prediction_out(prediction)


@router.get("/{device_id}/risk/history", response_model=list[PredictionOut])
def prediction_history(
    device_id: str,
    limit: int = Query(default=20, ge=1, le=100),
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> list[PredictionOut]:
    _authorized_device(device_id, session_device_id, db)
    predictions = db.scalars(
        select(PredictionModel)
        .where(PredictionModel.device_id == device_id)
        .order_by(PredictionModel.id.desc())
        .limit(limit)
    ).all()
    return [_prediction_out(prediction) for prediction in predictions]
