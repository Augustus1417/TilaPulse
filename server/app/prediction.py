from collections.abc import Sequence
from pathlib import Path
from typing import Any

from app.bocpd import BOCPD
from app.core.ai_config import AI_CONFIG, SYNTHETIC_MODEL_NOTICE
from app.lstm import load_lstm_model
from app.preprocessing import SensorPreprocessor


class PredictionService:
    def __init__(self, model_path: str, alpha: float, beta: float, window_size: int) -> None:
        if abs(alpha + beta - 1.0) > 1e-6 or min(alpha, beta) < 0:
            raise ValueError("prediction weights must be non-negative and sum to 1")
        self.model_path = Path(model_path)
        self.alpha = alpha
        self.beta = beta
        self.preprocessor = SensorPreprocessor(window_size, means=None, scales=None)
        self.model: Any | None = None
        self.metadata: dict[str, Any] | None = None

    def load_model(self) -> None:
        loaded = load_lstm_model(self.model_path)
        if loaded is None:
            self.model = None
            return
        self.model, self.metadata = loaded
        metadata_window = int(self.metadata["window_size"])
        if metadata_window != self.preprocessor.window_size:
            raise ValueError("checkpoint window size does not match service configuration")
        self.preprocessor = SensorPreprocessor.from_dict(self.metadata["scaler"], metadata_window)

    def predict(self, records: Sequence[dict[str, object]]) -> dict[str, float | str]:
        if self.model is None:
            raise FileNotFoundError(f"Trained LSTM model not found at {self.model_path}. Run scripts/train_lstm.py first.")
        window = self.preprocessor.window(records)
        detector = BOCPD()
        for row in window:
            detector.update(row)
        import torch

        with torch.no_grad():
            lstm_probability = float(self.model(torch.tensor([window], dtype=torch.float32)).item())
        bocpd_probability = detector.get_change_probability()
        return {
            "lstm_probability": round(lstm_probability, 6),
            "bocpd_probability": round(bocpd_probability, 6),
            "risk_score": round(self.alpha * lstm_probability + self.beta * bocpd_probability, 6),
            "synthetic_model_notice": SYNTHETIC_MODEL_NOTICE,
        }