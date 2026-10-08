from collections.abc import Mapping, Sequence
from typing import Any

from app.core.ai_config import AI_CONFIG, FEATURE_NAMES


class SensorPreprocessor:
    """Shared resampling, last-observation imputation, and train-fitted z-score."""

    def __init__(self, window_size: int = AI_CONFIG.window_size,
                 means: Sequence[float] | None = None,
                 scales: Sequence[float] | None = None) -> None:
        if window_size < 1:
            raise ValueError("window_size must be positive")
        if (means is None) != (scales is None):
            raise ValueError("means and scales must be supplied together")
        self.window_size = window_size
        self.means = tuple(float(value) for value in (means or (0.0, 0.0, 0.0)))
        self.scales = tuple(float(value) for value in (scales or (1.0, 1.0, 1.0)))
        if len(self.means) != 3 or len(self.scales) != 3 or any(value <= 0 for value in self.scales):
            raise ValueError("normalization statistics are invalid")
        self.fitted = means is not None

    def _raw(self, records: Sequence[Mapping[str, object]]) -> list[list[float]]:
        previous = [0.0, 0.0, 0.0]
        output: list[list[float]] = []
        for record in records:
            row: list[float] = []
            for index, name in enumerate(FEATURE_NAMES):
                try:
                    value = float(record.get(name))  # type: ignore[arg-type]
                except (TypeError, ValueError):
                    value = previous[index]
                if not value == value or abs(value) == float("inf"):
                    value = previous[index]
                previous[index] = value
                row.append(value)
            output.append(row)
        return output

    def fit(self, sequences: Sequence[Sequence[Mapping[str, object]]]) -> "SensorPreprocessor":
        raw_sequences = [self._raw(sequence) for sequence in sequences]
        count = sum(len(sequence) for sequence in raw_sequences)
        if not count:
            raise ValueError("cannot fit scaler on empty data")
        means = []
        scales = []
        for index in range(3):
            mean = sum(row[index] for sequence in raw_sequences for row in sequence) / count
            variance = sum((row[index] - mean) ** 2 for sequence in raw_sequences for row in sequence) / max(1, count - 1)
            means.append(mean)
            scales.append(max(variance ** 0.5, 1e-6))
        self.means, self.scales, self.fitted = tuple(means), tuple(scales), True
        return self

    def transform(self, records: Sequence[Mapping[str, object]]) -> list[list[float]]:
        if not self.fitted:
            raise RuntimeError("fit the preprocessor on training data before transforming")
        return [[(value - self.means[index]) / self.scales[index] for index, value in enumerate(row)]
                for row in self._raw(records)]

    def window(self, records: Sequence[Mapping[str, object]]) -> list[list[float]]:
        transformed = self.transform(records)
        padding = [transformed[0]] * (self.window_size - len(transformed)) if transformed else [
            [0.0] * 3
        ] * self.window_size
        return (padding + transformed)[-self.window_size:]

    def to_dict(self) -> dict[str, Any]:
        return {"feature_order": list(FEATURE_NAMES), "means": list(self.means), "scales": list(self.scales)}

    @classmethod
    def from_dict(cls, data: Mapping[str, Any], window_size: int) -> "SensorPreprocessor":
        if tuple(data.get("feature_order", ())) != FEATURE_NAMES:
            raise ValueError("checkpoint feature order does not match the API")
        return cls(window_size, data["means"], data["scales"])
