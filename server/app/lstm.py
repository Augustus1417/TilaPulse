from pathlib import Path
from typing import Any


def _torch() -> Any:
    try:
        import torch
        from torch import nn
    except ImportError as exc:
        raise RuntimeError("PyTorch is required for LSTM predictions; install requirements.txt") from exc
    return torch, nn


def build_lstm_model(input_size: int = 3, hidden_size: int = 32) -> Any:
    torch, nn = _torch()

    class UnidirectionalLSTM(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.lstm = nn.LSTM(input_size, hidden_size, batch_first=True)
            self.output = nn.Sequential(nn.Linear(hidden_size, 1), nn.Sigmoid())

        def forward(self, inputs: Any) -> Any:
            outputs, _ = self.lstm(inputs)
            return self.output(outputs[:, -1, :]).squeeze(-1)

    return UnidirectionalLSTM()


def load_lstm_model(path: str | Path) -> Any | None:
    model_path = Path(path)
    if not model_path.exists():
        return None
    torch, _ = _torch()
    model = build_lstm_model()
    model.load_state_dict(torch.load(model_path, map_location="cpu", weights_only=True))
    model.eval()
    return model