from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import PredictionModel, ReadingModel
from app.prediction import PredictionService
from app.routers.readings import now_local


def _risk_label(risk_score: float) -> str:
    if risk_score < settings.prediction_risk_low_threshold:
        return "low"
    if risk_score < settings.prediction_risk_high_threshold:
        return "moderate"
    return "high"


def run_prediction(
    db: Session,
    device_id: str,
    source: str,
    prediction_service: PredictionService,
) -> PredictionModel:
    records = db.scalars(
        select(ReadingModel)
        .where(ReadingModel.device_id == device_id)
        .order_by(ReadingModel.id.asc())
    ).all()
    if not records:
        raise ValueError("No readings found for device")
    record_data = [
        {
            "device_id": reading.device_id,
            "temperature": reading.temperature,
            "ph": reading.ph,
            "dissolved_oxygen": reading.dissolved_oxygen,
        }
        for reading in records
    ]
    result = prediction_service.predict(record_data)
    risk_score = float(result["risk_score"])
    prediction = PredictionModel(
        device_id=device_id,
        risk_score=risk_score,
        lstm_probability=float(result["lstm_probability"]),
        bocpd_change_point_probability=float(result["bocpd_probability"]),
        risk_label=_risk_label(risk_score),
        created_at=now_local(),
        source=source,
    )
    db.add(prediction)
    db.commit()
    db.refresh(prediction)
    return prediction
