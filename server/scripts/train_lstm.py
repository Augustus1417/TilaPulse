from pathlib import Path
import random
import sys

import torch
from torch import nn

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.lstm import build_lstm_model
from app.preprocessing import SensorPreprocessor
from app.synthetic_data import generate_synthetic_sequences


def main() -> None:
    random.seed(42)
    torch.manual_seed(42)
    sequences = list(generate_synthetic_sequences(count=200, sequence_length=20))
    preprocessor = SensorPreprocessor()
    inputs = torch.tensor(
        [preprocessor.window([{"temperature": row[0], "ph": row[1], "dissolved_oxygen": row[2]} for row in sequence]) for sequence, _ in sequences],
        dtype=torch.float32,
    )
    labels = torch.tensor([label for _, label in sequences], dtype=torch.float32)
    model = build_lstm_model()
    optimizer = torch.optim.Adam(model.parameters(), lr=0.01)
    loss_function = nn.BCELoss()
    for _ in range(20):
        optimizer.zero_grad()
        loss_function(model(inputs), labels).backward()
        optimizer.step()
    output_path = Path(__file__).resolve().parents[1] / "models" / "lstm_model.pt"
    output_path.parent.mkdir(exist_ok=True)
    torch.save(model.state_dict(), output_path)
    print(f"Saved synthetic development model to {output_path}")


if __name__ == "__main__":
    main()