from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import verify_device_session
from app.db import get_db
from app.models import DeviceModel, PredictionModel
from app.core.config import settings
from app.prediction_runner import run_prediction
from app.schemas import PredictionOut


router = APIRouter(prefix="/api/devices", tags=["predictions"])


def _risk_label(risk_score: float) -> str:
    if risk_score < settings.prediction_risk_low_threshold:
        return "low"
    if risk_score < settings.prediction_risk_high_threshold:
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
    try:
        prediction = run_prediction(db, device_id, "manual", request.app.state.prediction_service)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except (FileNotFoundError, RuntimeError) as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
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
