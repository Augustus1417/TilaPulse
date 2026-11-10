"""Train the CPU LSTM on labelled sensor sequences."""

import argparse
import csv
from pathlib import Path
import json
import random
import sys
from typing import Any, Sequence

import torch
from torch import nn

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.ai_config import AI_CONFIG, FEATURE_NAMES
from app.lstm import build_lstm_model
from app.preprocessing import SensorPreprocessor
from app.synthetic_data import generate_synthetic_sequences, records_to_dicts


def _csv_sequences(
    path: Path,
    window_size: int,
    horizon: int,
) -> tuple[list[tuple[list[list[float | None]], int]], dict[str, int]]:
    required = {"site", "date", "session", "temp_c", "ph", "do_mgl", "risk_level_code"}
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"CSV contains no rows: {path}")
    missing = required - set(rows[0])
    if missing:
        raise ValueError(f"CSV is missing required columns: {', '.join(sorted(missing))}")

    grouped: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        grouped.setdefault(row["site"].strip(), []).append(row)

    sequences: list[tuple[list[list[float | None]], int]] = []
    site_counts: dict[str, int] = {}
    session_order = {"AM": 0, "PM": 1}
    for site, site_rows in grouped.items():
        site_rows.sort(key=lambda row: (row["date"], session_order.get(row["session"].upper(), 2)))
        samples = 0
        for target_index in range(window_size + horizon, len(site_rows)):
            context = site_rows[target_index - horizon - window_size : target_index - horizon]
            try:
                label = int(site_rows[target_index]["risk_level_code"]) >= 1
            except (TypeError, ValueError) as exc:
                raise ValueError(f"invalid risk_level_code for site {site}") from exc
            records: list[list[float | None]] = []
            for row in context:
                values: list[float | None] = []
                for column in ("temp_c", "ph", "do_mgl"):
                    raw = row[column].strip()
                    values.append(None if not raw else float(raw))
                records.append(values)
            sequences.append((records, int(label)))
            samples += 1
        site_counts[site] = samples
    if not sequences:
        raise ValueError("CSV does not contain enough rows for one training window")
    return sequences, site_counts


def _temporal_split(
    sequences: Sequence[tuple[list[list[float | None]], int]],
    site_counts: dict[str, int],
) -> tuple[list[tuple[list[list[float | None]], int]], ...]:
    splits: list[list[tuple[list[list[float | None]], int]]] = [[], [], []]
    offset = 0
    for count in site_counts.values():
        train_end = max(1, int(count * 0.70))
        validation_end = max(train_end + 1, int(count * 0.85))
        validation_end = min(validation_end, count - 1)
        site_sequences = sequences[offset : offset + count]
        splits[0].extend(site_sequences[:train_end])
        splits[1].extend(site_sequences[train_end:validation_end])
        splits[2].extend(site_sequences[validation_end:])
        offset += count
    if not all(splits):
        raise ValueError("temporal split did not produce train, validation, and test samples")
    return splits[0], splits[1], splits[2]


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
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--csv",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "water_parameters_labeled.csv",
        help="labelled sensor CSV; omit to use the repository dataset",
    )
    parser.add_argument("--synthetic", action="store_true", help="use the legacy generated dataset")
    args = parser.parse_args()
    seed = 42
    random.seed(seed)
    torch.manual_seed(seed)
    if args.synthetic:
        sequences = list(generate_synthetic_sequences(count=300, seed=seed))
        random.Random(seed).shuffle(sequences)
        train, validation, test = sequences[:210], sequences[210:255], sequences[255:]
        dataset_metadata: dict[str, Any] = {"synthetic_data": True}
    else:
        sequences, site_counts = _csv_sequences(args.csv, AI_CONFIG.window_size, AI_CONFIG.horizon)
        train, validation, test = _temporal_split(sequences, site_counts)
        dataset_metadata = {
            "synthetic_data": True,
            "source": args.csv.name,
            "source_labels": "synthetic_rule_based_v1",
            "site_sequence_counts": site_counts,
        }
    preprocessor = SensorPreprocessor(AI_CONFIG.window_size)
    preprocessor.fit([records_to_dicts(rows) for rows, _ in train])

    def tensors(items: list[tuple[list[list[float | None]], int]]) -> tuple[torch.Tensor, torch.Tensor]:
        inputs = [
            preprocessor.window(records_to_dicts(rows if not args.synthetic else rows[:-AI_CONFIG.horizon]))
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
        "training_config": {
            "seed": seed,
            "validation_pr_auc": best_score,
            "label_definition": "risk_level_code >= 1",
            **dataset_metadata,
        },
        **dataset_metadata,
        "split_sizes": {"train_sequences": len(train), "validation_sequences": len(validation), "test_sequences": len(test)},
    }
    output_path = Path(__file__).resolve().parents[1] / "models" / "lstm_model.pt"
    output_path.parent.mkdir(exist_ok=True)
    torch.save({"state_dict": model.state_dict(), "metadata": metadata}, output_path)
    (output_path.with_suffix(".json")).write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"Saved labelled checkpoint to {output_path}; validation PR-AUC={best_score:.3f}")


if __name__ == "__main__":
    main()
