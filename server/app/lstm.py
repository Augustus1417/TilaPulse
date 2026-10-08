from pathlib import Path
from typing import Any

from app.core.ai_config import FEATURE_NAMES

def _torch() -> Any:
    try:
        import torch
        from torch import nn
    except ImportError as exc:
        raise RuntimeError("PyTorch is required for LSTM predictions; install requirements.txt") from exc
    return torch, nn


def build_lstm_model(input_size: int = 3, hidden_size: int = 32) -> Any:
    _, nn = _torch()

    class UnidirectionalLSTM(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.lstm = nn.LSTM(input_size, hidden_size, batch_first=True)
            self.output = nn.Sequential(nn.Linear(hidden_size, 1), nn.Sigmoid())

        def forward(self, inputs: Any) -> Any:
            outputs, _ = self.lstm(inputs)
            return self.output(outputs[:, -1, :]).squeeze(-1)

    return UnidirectionalLSTM()


def load_lstm_model(path: str | Path) -> tuple[Any, dict[str, Any]] | None:
    model_path = Path(path)
    if not model_path.exists():
        return None
    torch, _ = _torch()
    checkpoint = torch.load(model_path, map_location="cpu", weights_only=True)
    if not isinstance(checkpoint, dict) or "state_dict" not in checkpoint or "metadata" not in checkpoint:
        raise ValueError("LSTM checkpoint is missing validated metadata")
    metadata = checkpoint["metadata"]
    if metadata.get("feature_order") != list(FEATURE_NAMES) or metadata.get("synthetic_data") is not True:
        raise ValueError("LSTM checkpoint metadata is incompatible or not synthetic-labelled")
    model = build_lstm_model(3, int(metadata["hidden_size"]))
    model.load_state_dict(checkpoint["state_dict"])
    model.eval()
    return model, metadata