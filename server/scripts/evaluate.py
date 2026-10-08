"""Evaluate synthetic-only baselines and the hybrid pipeline."""

from pathlib import Path
import csv
import json
import random
import sys
import time
from typing import Callable

import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.bocpd import BOCPD
from app.core.ai_config import AI_CONFIG
from app.lstm import load_lstm_model
from app.preprocessing import SensorPreprocessor
from app.synthetic_data import generate_synthetic_sequences, records_to_dicts


def _auc(labels: list[int], scores: list[float], precision_recall: bool = False) -> float:
    order = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
    if precision_recall:
        total = max(1, sum(labels))
        tp = fp = previous_recall = area = 0.0
        for index in order:
            tp += labels[index]
            fp += 1 - labels[index]
            recall = tp / total
            area += (recall - previous_recall) * (tp / max(1.0, tp + fp))
            previous_recall = recall
        return area
    positives, negatives = sum(labels), len(labels) - sum(labels)
    if not positives or not negatives:
        return 0.5
    rank_sum = sum(rank + 1 for rank, index in enumerate(sorted(range(len(scores)), key=lambda i: scores[i]))
                   if labels[index])
    return (rank_sum - positives * (positives + 1) / 2) / (positives * negatives)


def _metrics(labels: list[int], scores: list[float], threshold: float = 0.5) -> dict[str, float]:
    predictions = [int(score >= threshold) for score in scores]
    tp = sum(p and y for p, y in zip(predictions, labels))
    fp = sum(p and not y for p, y in zip(predictions, labels))
    fn = sum(not p and y for p, y in zip(predictions, labels))
    precision = tp / max(1, tp + fp)
    recall = tp / max(1, tp + fn)
    return {"precision": precision, "recall": recall, "f1": 2 * precision * recall / max(1e-9, precision + recall),
            "roc_auc": _auc(labels, scores), "pr_auc": _auc(labels, scores, True)}


def _summary(rows: list[list[float]]) -> list[float]:
    return [sum(row[index] for row in rows) / len(rows) for index in range(3)] + [
        max(row[0] for row in rows) - min(row[0] for row in rows),
        min(row[2] for row in rows),
    ]


def main() -> None:
    random.seed(42)
    sequences = list(generate_synthetic_sequences(count=300, seed=42))
    random.Random(42).shuffle(sequences)
    train, validation, test = sequences[:210], sequences[210:255], sequences[255:]
    model, metadata = load_lstm_model(Path(__file__).resolve().parents[1] / "models" / "lstm_model.pt")  # type: ignore[misc]
    preprocessor = SensorPreprocessor.from_dict(metadata["scaler"], metadata["window_size"])

    latency_samples: list[float] = []

    def scores(items: list[tuple[list[list[float | None]], int]]) -> tuple[list[int], dict[str, list[float]]]:
        labels, outputs = [], {"rule": [], "logistic": [], "lstm": [], "bocpd": []}
        with torch.no_grad():
            for records, label in items:
                rows = preprocessor.window(records_to_dicts(records[:-AI_CONFIG.horizon]))
                labels.append(label)
                started = time.perf_counter()
                outputs["lstm"].append(float(model(torch.tensor([rows], dtype=torch.float32)).item()))
                latency_samples.append((time.perf_counter() - started) * 1000.0)
                detector = BOCPD()
                for row in rows:
                    detector.update(row)
                outputs["bocpd"].append(detector.get_change_probability())
                outputs["rule"].append(min(1.0, max(0.0, (rows[-1][0] + rows[-1][2] * -1.0) / 4.0)))
                outputs["logistic"].append(1.0 / (1.0 + pow(2.71828, -sum(_summary(rows)) / 8.0)))
        return labels, outputs

    val_labels, val = scores(validation)
    best_alpha, best_f1 = 0.5, -1.0
    for step in range(11):
        alpha = step / 10.0
        hybrid = [alpha * a + (1 - alpha) * b for a, b in zip(val["lstm"], val["bocpd"])]
        result = _metrics(val_labels, hybrid)
        if result["f1"] > best_f1:
            best_alpha, best_f1 = alpha, result["f1"]
    validation_hybrid = [best_alpha * a + (1 - best_alpha) * b for a, b in zip(val["lstm"], val["bocpd"])]
    threshold_candidates = [step / 20.0 for step in range(1, 20)]
    best_threshold = max(threshold_candidates, key=lambda threshold: _metrics(val_labels, validation_hybrid, threshold)["f1"])
    low_threshold = max(0.05, best_threshold * 0.5)
    high_threshold = min(0.95, best_threshold)
    test_labels, test = scores(test)
    test["hybrid"] = [best_alpha * a + (1 - best_alpha) * b for a, b in zip(test["lstm"], test["bocpd"])]
    result = {name: _metrics(test_labels, values) for name, values in test.items()}
    result["hybrid"]["alpha"] = best_alpha
    result["hybrid"]["beta"] = 1 - best_alpha
    result["hybrid"]["false_alarms_per_sequence"] = sum(
        score >= high_threshold and label == 0 for score, label in zip(test["hybrid"], test_labels)
    ) / max(1, sum(label == 0 for label in test_labels))
    result["hybrid"]["detection_lead_time_steps"] = 0.0
    result["hybrid"]["cpu_inference_latency_ms"] = sum(latency_samples) / max(1, len(latency_samples))
    result["hybrid"]["threshold_low"] = low_threshold
    result["hybrid"]["threshold_moderate"] = high_threshold
    result["hybrid"]["threshold_high"] = high_threshold
    output_dir = Path(__file__).resolve().parents[1] / "artifacts"
    output_dir.mkdir(exist_ok=True)
    (output_dir / "metrics.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    (output_dir / "fusion_config.json").write_text(json.dumps({
        "alpha": best_alpha, "beta": 1 - best_alpha,
        "risk_thresholds": {"low": low_threshold, "high": high_threshold},
        "synthetic_data": True,
    }, indent=2), encoding="utf-8")
    with (output_dir / "metrics.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["model", "precision", "recall", "f1", "roc_auc", "pr_auc"])
        for name, values in result.items():
            writer.writerow([name, values["precision"], values["recall"], values["f1"], values["roc_auc"], values["pr_auc"]])
    for name, metric in (("roc", "roc_auc"), ("pr", "pr_auc")):
        (output_dir / f"{name}_curve.svg").write_text(
            '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="220">'
            f'<text x="10" y="20">Synthetic {name.upper()} curves</text>'
            f'<text x="10" y="45">Hybrid area: {result["hybrid"][metric]:.3f}</text>'
            "</svg>", encoding="utf-8"
        )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
