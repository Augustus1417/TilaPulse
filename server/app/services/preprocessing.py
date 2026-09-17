from collections.abc import Mapping, Sequence


FEATURE_NAMES = ("temperature", "ph", "dissolved_oxygen")


class SensorPreprocessor:
    """Convert sensor records into normalized, fixed-length model windows."""

    def __init__(
        self,
        window_size: int = 20,
        means: Sequence[float] = (28.0, 7.2, 5.5),
        scales: Sequence[float] = (4.0, 1.5, 3.0),
    ) -> None:
        if window_size < 1:
            raise ValueError("window_size must be positive")
        if len(means) != 3 or len(scales) != 3 or any(scale <= 0 for scale in scales):
            raise ValueError("means and scales must contain three valid values")
        self.window_size = window_size
        self.means = tuple(means)
        self.scales = tuple(scales)

    def _value(self, record: Mapping[str, object], name: str, fallback: float) -> float:
        value = record.get(name)
        if value is None:
            return fallback
        try:
            return float(value)
        except (TypeError, ValueError):
            return fallback

    def normalize(self, records: Sequence[Mapping[str, object]]) -> list[list[float]]:
        previous = list(self.means)
        normalized: list[list[float]] = []
        for record in records:
            values: list[float] = []
            for index, name in enumerate(FEATURE_NAMES):
                value = self._value(record, name, previous[index])
                previous[index] = value
                values.append((value - self.means[index]) / self.scales[index])
            normalized.append(values)
        return normalized

    def window(self, records: Sequence[Mapping[str, object]]) -> list[list[float]]:
        normalized = self.normalize(records)
        if len(normalized) < self.window_size:
            padding = [normalized[0]] * (self.window_size - len(normalized)) if normalized else [[0.0] * 3] * self.window_size
            normalized = padding + normalized
        return normalized[-self.window_size:]

    def windows(self, records: Sequence[Mapping[str, object]]) -> list[list[list[float]]]:
        normalized = self.normalize(records)
        return [normalized[index - self.window_size + 1:index + 1] for index in range(self.window_size - 1, len(normalized))]