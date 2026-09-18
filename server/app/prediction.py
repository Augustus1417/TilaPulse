from collections.abc import Sequence
from pathlib import Path

from fastapi import APIRouter, HTTPException

from app.bocpd import BOCPD
from app.core.config import settings
from app.lstm import load_lstm_model
from app.preprocessing import SensorPreprocessor
from app.schemas import PredictionRequest, PredictionResponse


class PredictionService:
    def __init__(self, model_path: str, alpha: float, beta: float, window_size: int) -> None:
        if abs(alpha + beta - 1.0) > 1e-6 or min(alpha, beta) < 0:
            raise ValueError("prediction weights must be non-negative and sum to 1")
        self.model_path = Path(model_path)
        self.alpha = alpha
        self.beta = beta
        self.preprocessor = SensorPreprocessor(window_size=window_size)
        self._model = None

    def predict(self, records: Sequence[dict[str, object]]) -> dict[str, float | str]:
        model = self._model
        if model is None:
            model = load_lstm_model(self.model_path)
            self._model = model
        if model is None:
            raise FileNotFoundError(
                f"Trained LSTM model not found at {self.model_path}. Run scripts/train_lstm.py first."
            )

        window = self.preprocessor.window(records)
        detector = BOCPD()
        for row in window:
            detector.update(row)
        import torch

        with torch.no_grad():
            lstm_probability = float(model(torch.tensor([window], dtype=torch.float32)).item())
        bocpd_probability = detector.get_change_probability()
        risk_score = self.alpha * lstm_probability + self.beta * bocpd_probability
        return {
            "lstm_probability": round(lstm_probability, 6),
            "bocpd_probability": round(bocpd_probability, 6),
            "risk_score": round(risk_score, 6),
            "synthetic_model_notice": "A checkpoint trained on SYNTHETIC data is for software development only, not real disease evidence.",
        }


prediction_service = PredictionService(
    model_path=settings.lstm_model_path,
    alpha=settings.prediction_alpha,
    beta=settings.prediction_beta,
    window_size=settings.prediction_window_size,
)
router = APIRouter(prefix="/api/predict", tags=["predictions"])


@router.post("", response_model=PredictionResponse)
def predict(request: PredictionRequest) -> PredictionResponse:
    try:
        result = prediction_service.predict([reading.model_dump() for reading in request.readings])
    except (FileNotFoundError, RuntimeError) as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return PredictionResponse(**result)