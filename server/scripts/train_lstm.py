from pathlib import Path
import random
import sys

import torch
from torch import nn

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.models.lstm_model import build_lstm_model
from app.services.preprocessing import SensorPreprocessor
from app.services.synthetic_data import generate_synthetic_sequences


def main() -> None:
    seed = 42
    random.seed(seed)
    torch.manual_seed(seed)
    sequences = list(generate_synthetic_sequences(count=200, sequence_length=20, seed=seed))
    preprocessor = SensorPreprocessor(window_size=20)
    inputs = torch.tensor(
        [
            preprocessor.window(
                [{"temperature": row[0], "ph": row[1], "dissolved_oxygen": row[2]} for row in sequence]
            )
            for sequence, _ in sequences
        ],
        dtype=torch.float32,
    )
    labels = torch.tensor([label for _, label in sequences], dtype=torch.float32)
    model = build_lstm_model()
    optimizer = torch.optim.Adam(model.parameters(), lr=0.01)
    loss_function = nn.BCELoss()
    for epoch in range(20):
        optimizer.zero_grad()
        loss = loss_function(model(inputs), labels)
        loss.backward()
        optimizer.step()
        if epoch == 0 or (epoch + 1) % 5 == 0:
            print(f"SYNTHETIC training epoch {epoch + 1}/20 loss={loss.item():.4f}")
    output_path = Path(__file__).resolve().parents[1] / "models" / "lstm_model.pt"
    output_path.parent.mkdir(exist_ok=True)
    torch.save(model.state_dict(), output_path)
    print(f"Saved SYNTHETIC development model to {output_path}")
    print("This model is not evidence of real tilapia disease prediction accuracy.")


if __name__ == "__main__":
    main()