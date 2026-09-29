from collections.abc import Mapping, Sequence


FEATURE_NAMES = ("temperature", "ph", "dissolved_oxygen")


class SensorPreprocessor:
    def __init__(
        self,
        window_size: int = 20,
        means: Sequence[float] = (28.0, 7.2, 5.5),
        scales: Sequence[float] = (4.0, 1.5, 3.0),
    ) -> None:
        if window_size < 1 or len(means) != 3 or len(scales) != 3 or any(scale <= 0 for scale in scales):
            raise ValueError("window_size and feature normalization values are invalid")
        self.window_size = window_size
        self.means = tuple(means)
        self.scales = tuple(scales)

    def normalize(self, records: Sequence[Mapping[str, object]]) -> list[list[float]]:
        previous = list(self.means)
        normalized: list[list[float]] = []
        for record in records:
            values = []
            for index, name in enumerate(FEATURE_NAMES):
                try:
                    value = float(record.get(name, previous[index]))
                except (TypeError, ValueError):
                    value = previous[index]
                previous[index] = value
                values.append((value - self.means[index]) / self.scales[index])
            normalized.append(values)
        return normalized

    def window(self, records: Sequence[Mapping[str, object]]) -> list[list[float]]:
        normalized = self.normalize(records)
        padding = [normalized[0]] * (self.window_size - len(normalized)) if normalized else [[0.0] * 3] * self.window_size
        return (padding + normalized)[-self.window_size:]