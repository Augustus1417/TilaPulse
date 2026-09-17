from collections.abc import Sequence
from pathlib import Path

from app.services.bocpd import BOCPD
from app.services.preprocessing import SensorPreprocessor


class PredictionService:
    def __init__(self, model_path: str, alpha: float, beta: float, window_size: int) -> None:
        if abs(alpha + beta - 1.0) > 1e-6 or min(alpha, beta) < 0:
            raise ValueError("prediction weights must be non-negative and sum to 1")
        self.model_path = Path(model_path)
        self.alpha = alpha
        self.beta = beta
        self.preprocessor = SensorPreprocessor(window_size=window_size)
        self._model = None

    def _get_model(self):
        if self._model is None:
            from app.models.lstm_model import load_lstm_model
            self._model = load_lstm_model(self.model_path)
        return self._model

    def predict(self, records: Sequence[dict[str, object]]) -> dict[str, float | str]:
        model = self._get_model()
        if model is None:
            raise FileNotFoundError(f"Trained LSTM model not found at {self.model_path}. Run scripts/train_lstm.py first.")
        window = self.preprocessor.window(records)
        detector = BOCPD()
        bocpd_probability = detector.get_change_probability()
        for row in window:
            bocpd_probability = detector.update(row)
        import torch
        with torch.no_grad():
            lstm_probability = float(model(torch.tensor([window], dtype=torch.float32)).item())
        risk_score = self.alpha * lstm_probability + self.beta * bocpd_probability
        return {
            "lstm_probability": round(lstm_probability, 6),
            "bocpd_probability": round(bocpd_probability, 6),
            "risk_score": round(risk_score, 6),
            "synthetic_model_notice": "A checkpoint trained on SYNTHETIC data is for software development only, not real disease evidence.",
        }