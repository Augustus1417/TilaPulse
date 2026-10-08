"""Train the CPU LSTM on whole-sequence synthetic splits."""

from pathlib import Path
import json
import random
import sys
from typing import Any

import torch
from torch import nn

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.ai_config import AI_CONFIG, FEATURE_NAMES
from app.lstm import build_lstm_model
from app.preprocessing import SensorPreprocessor
from app.synthetic_data import generate_synthetic_sequences, records_to_dicts


def _pr_auc(labels: list[int], scores: list[float]) -> float:
    order = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
    positives = max(1, sum(labels))
    tp = fp = previous_recall = area = 0.0
    for index in order:
        if labels[index]:
            tp += 1
        else:
            fp += 1
        recall = tp / positives
        precision = tp / max(1.0, tp + fp)
        area += (recall - previous_recall) * precision
        previous_recall = recall
    return area


def main() -> None:
    seed = 42
    random.seed(seed)
    torch.manual_seed(seed)
    sequences = list(generate_synthetic_sequences(count=300, seed=seed))
    random.Random(seed).shuffle(sequences)
    train, validation, test = sequences[:210], sequences[210:255], sequences[255:]
    preprocessor = SensorPreprocessor(AI_CONFIG.window_size)
    preprocessor.fit([records_to_dicts(rows) for rows, _ in train])

    def tensors(items: list[tuple[list[list[float | None]], int]]) -> tuple[torch.Tensor, torch.Tensor]:
        inputs = [
            preprocessor.window(records_to_dicts(rows[:-AI_CONFIG.horizon]))
            for rows, _ in items
        ]
        return torch.tensor(inputs, dtype=torch.float32), torch.tensor(
            [label for _, label in items], dtype=torch.float32
        )

    train_x, train_y = tensors(train)
    val_x, val_y = tensors(validation)
    model = build_lstm_model(hidden_size=32)
    positive = float(train_y.sum())
    negative = float(len(train_y) - positive)
    pos_weight = torch.tensor(negative / max(positive, 1.0))
    loss_function = nn.BCEWithLogitsLoss(pos_weight=pos_weight)
    optimizer = torch.optim.Adam(model.parameters(), lr=0.003)
    best_state: dict[str, Any] | None = None
    best_score = -1.0
    patience = 0
    for _epoch in range(60):
        model.train()
        optimizer.zero_grad()
        # The model's sigmoid output is converted back to logits for the weighted loss.
        probabilities = model(train_x).clamp(1e-6, 1 - 1e-6)
        loss = loss_function(torch.logit(probabilities), train_y)
        loss.backward()
        optimizer.step()
        model.eval()
        with torch.no_grad():
            scores = model(val_x).tolist()
        score = _pr_auc([int(value) for value in val_y.tolist()], scores)
        if score > best_score + 1e-4:
            best_score = score
            best_state = {key: value.detach().cpu().clone() for key, value in model.state_dict().items()}
            patience = 0
        else:
            patience += 1
            if patience >= 8:
                break
    if best_state is None:
        raise RuntimeError("training did not produce a validation checkpoint")
    model.load_state_dict(best_state)
    metadata = {
        "feature_order": list(FEATURE_NAMES),
        "window_size": AI_CONFIG.window_size,
        "hidden_size": 32,
        "scaler": preprocessor.to_dict(),
        "training_config": {"seed": seed, "synthetic_data": True, "validation_pr_auc": best_score},
        "synthetic_data": True,
        "split_sizes": {"train_sequences": len(train), "validation_sequences": len(validation), "test_sequences": len(test)},
    }
    output_path = Path(__file__).resolve().parents[1] / "models" / "lstm_model.pt"
    output_path.parent.mkdir(exist_ok=True)
    torch.save({"state_dict": model.state_dict(), "metadata": metadata}, output_path)
    (output_path.with_suffix(".json")).write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"Saved synthetic checkpoint to {output_path}; validation PR-AUC={best_score:.3f}")


if __name__ == "__main__":
    main()
