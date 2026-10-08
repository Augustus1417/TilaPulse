"""Adams-MacKay BOCPD with independent Normal-Gamma feature models.

The three sensors are treated as conditionally independent, so their
log-predictive probabilities are summed. The reported score is posterior mass
on short run lengths after warm-up, not P(run_length=0), which equals hazard.
"""

import math
from collections.abc import Sequence

from app.core.ai_config import AI_CONFIG


def _logsum(values: Sequence[float]) -> float:
    if not values:
        return float("-inf")
    peak = max(values)
    return peak + math.log(sum(math.exp(value - peak) for value in values))


class BOCPD:
    def __init__(
        self,
        hazard: float = AI_CONFIG.bocpd_hazard,
        sensitivity: float = 1.0,
        max_run_length: int = AI_CONFIG.bocpd_max_run_length,
        short_run_length: int = AI_CONFIG.bocpd_short_run_length,
        warmup: int = AI_CONFIG.bocpd_warmup,
    ) -> None:
        if not 0 < hazard < 1 or max_run_length < 2 or short_run_length < 0 or warmup < 0:
            raise ValueError("invalid BOCPD configuration")
        self.hazard, self.sensitivity = hazard, max(0.0, sensitivity)
        self.max_run_length, self.short_run_length, self.warmup = max_run_length, short_run_length, warmup
        self.reset()

    def reset(self) -> None:
        self._run_log: list[float] = [0.0]
        self._states: list[list[tuple[float, float, float, float]]] = [[
            (0.0, 1.0, 1.0, 1.0) for _ in range(3)
        ]]
        self._count = 0
        self._change_probability = 0.0

    @staticmethod
    def _predictive(value: float, state: tuple[float, float, float, float]) -> float:
        mean, kappa, alpha, beta = state
        nu = 2.0 * alpha
        scale = beta * (kappa + 1.0) / (alpha * kappa)
        scale = max(scale, 1e-12)
        return (
            math.lgamma((nu + 1.0) / 2.0) - math.lgamma(nu / 2.0)
            - 0.5 * (math.log(nu * math.pi * scale))
            - ((nu + 1.0) / 2.0) * math.log1p((value - mean) ** 2 / (nu * scale))
        )

    @staticmethod
    def _update(value: float, state: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
        mean, kappa, alpha, beta = state
        new_kappa = kappa + 1.0
        delta = value - mean
        new_mean = mean + delta / new_kappa
        new_alpha = alpha + 0.5
        new_beta = beta + 0.5 * kappa * delta * delta / new_kappa
        return new_mean, new_kappa, new_alpha, new_beta

    def update(self, observation: Sequence[float]) -> float:
        if len(observation) != 3:
            raise ValueError("BOCPD expects temperature, pH, dissolved_oxygen")
        valid = [float(value) for value in observation]
        valid = [value if math.isfinite(value) else float("nan") for value in valid]
        predictive = [
            sum(self._predictive(value, self._states[index][feature]) for feature, value in enumerate(valid)
                if math.isfinite(value))
            for index in range(len(self._run_log))
        ]
        growth = [self._run_log[index] + math.log1p(-self.hazard) + self.sensitivity * predictive[index]
                  for index in range(len(self._run_log))]
        change = _logsum([self._run_log[index] + math.log(self.hazard) + self.sensitivity * predictive[index]
                         for index in range(len(self._run_log))])
        new_log = [change] + growth[: self.max_run_length]
        normalizer = _logsum(new_log)
        if not math.isfinite(normalizer):
            return self._change_probability
        new_log = [value - normalizer for value in new_log]
        base = [(0.0, 1.0, 1.0, 1.0) for _ in range(3)]
        new_states = [base]
        for state in self._states[: self.max_run_length]:
            new_states.append([
                self._update(value, state[feature]) if math.isfinite(value) else state[feature]
                for feature, value in enumerate(valid)
            ])
        self._run_log, self._states = new_log, new_states
        self._count += 1
        short = min(self.short_run_length + 1, len(new_log))
        self._change_probability = 0.0 if self._count < self.warmup else min(
            1.0, max(0.0, sum(math.exp(value) for value in new_log[:short]))
        )
        return self._change_probability

    def get_change_probability(self) -> float:
        return self._change_probability
