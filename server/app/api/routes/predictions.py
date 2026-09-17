from fastapi import APIRouter, HTTPException

from app.core.config import settings
from app.schemas.prediction import PredictionRequest, PredictionResponse
from app.services.prediction import PredictionService


router = APIRouter(prefix="/api/predict", tags=["predictions"])
prediction_service = PredictionService(
    model_path=settings.lstm_model_path,
    alpha=settings.prediction_alpha,
    beta=settings.prediction_beta,
    window_size=settings.prediction_window_size,
)


@router.post("", response_model=PredictionResponse)
def predict(request: PredictionRequest) -> PredictionResponse:
    try:
        result = prediction_service.predict([reading.model_dump() for reading in request.readings])
    except (FileNotFoundError, RuntimeError) as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return PredictionResponse(**result)