import math
from collections.abc import Sequence


class BOCPD:
    """Small online change detector based on hazard and predictive surprise."""

    def __init__(self, hazard: float = 0.02, sensitivity: float = 1.0) -> None:
        if not 0 < hazard < 1:
            raise ValueError("hazard must be between 0 and 1")
        self.hazard = hazard
        self.sensitivity = sensitivity
        self.reset()

    def reset(self) -> None:
        self._count = 0
        self._mean: list[float] | None = None
        self._variance: list[float] | None = None
        self._change_probability = 0.0

    def update(self, observation: float | Sequence[float]) -> float:
        values = [float(observation)] if isinstance(observation, (int, float)) else [float(value) for value in observation]
        if not values:
            raise ValueError("observation cannot be empty")
        if self._mean is None:
            self._mean = values[:]
            self._variance = [1.0] * len(values)
            self._count = 1
            self._change_probability = self.hazard
            return self._change_probability
        if len(values) != len(self._mean):
            raise ValueError("observation size changed")
        distances = [abs(value - mean) / math.sqrt(max(variance, 1e-6)) for value, mean, variance in zip(values, self._mean, self._variance or [])]
        surprise = sum(distances) / len(distances)
        self._change_probability = min(1.0, self.hazard + (1 - self.hazard) * (1 - math.exp(-self.sensitivity * surprise)))
        self._count += 1
        learning_rate = 1 / min(self._count, 50)
        for index, value in enumerate(values):
            delta = value - self._mean[index]
            self._mean[index] += learning_rate * delta
            self._variance[index] = max(1e-6, (1 - learning_rate) * self._variance[index] + learning_rate * delta * delta)
        return self._change_probability

    def get_change_probability(self) -> float:
        return self._change_probability