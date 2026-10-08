"""Seeded synthetic sensor simulator; it is not a disease model."""

import math
import random
from collections.abc import Iterator

from app.core.ai_config import AI_CONFIG, FEATURE_NAMES


SCENARIOS = ("normal", "gradual_degradation", "abrupt_event", "stress_recovery", "noisy_normal")


def _onset_for(scenario: str, length: int, rng: random.Random) -> int | None:
    if scenario == "normal" or scenario == "noisy_normal":
        return None
    # The returned sequence is a context window followed by H forecast steps.
    # The onset is therefore sampled in that future horizon, with jitter to
    # keep the classes overlapping rather than making the task deterministic.
    return rng.randint(max(8, length - AI_CONFIG.horizon - 3), max(9, length - 1))


def _simulate(
    scenario: str, length: int, rng: random.Random
) -> tuple[list[list[float | None]], int | None]:
    onset = _onset_for(scenario, length, rng)
    state = [
        AI_CONFIG.temperature_baseline,
        AI_CONFIG.ph_baseline,
        AI_CONFIG.dissolved_oxygen_baseline,
    ]
    drift = [rng.uniform(-0.004, 0.004), rng.uniform(-0.001, 0.001), rng.uniform(-0.006, 0.006)]
    rows: list[list[float | None]] = []
    for step in range(length):
        daily = math.sin(2.0 * math.pi * step / 96.0)
        state[0] += drift[0]
        state[1] += drift[1]
        state[2] += drift[2]
        if scenario == "gradual_degradation" and onset is not None and step >= onset:
            progress = min(1.0, (step - onset + 1) / max(1, length - onset))
            state[0] += 0.045 * progress
            state[1] -= 0.008 * progress
            state[2] -= 0.075 * progress
        elif scenario == "abrupt_event" and onset is not None and step >= onset:
            state[0] += 0.10
            state[1] -= 0.015
            state[2] -= 0.55
        elif scenario == "stress_recovery" and onset is not None:
            distance = step - onset
            if 0 <= distance < 6:
                state[0] += 0.12
                state[2] -= 0.45
            elif distance >= 6:
                state = [value + (target - value) * 0.12 for value, target in zip(
                    state,
                    (AI_CONFIG.temperature_baseline, AI_CONFIG.ph_baseline, AI_CONFIG.dissolved_oxygen_baseline),
                )]
        noise_scale = 2.2 if scenario == "noisy_normal" else 1.0
        values = [
            state[0] + 0.55 * daily + rng.gauss(0, AI_CONFIG.temperature_noise * noise_scale),
            state[1] + 0.04 * daily + rng.gauss(0, AI_CONFIG.ph_noise * noise_scale),
            state[2] - 0.35 * daily + rng.gauss(0, AI_CONFIG.dissolved_oxygen_noise * noise_scale),
        ]
        row: list[float | None] = [
            None if rng.random() < AI_CONFIG.dropout_probability else value for value in values
        ]
        if rng.random() < 0.015:
            index = rng.randrange(3)
            if row[index] is not None:
                row[index] += rng.choice((-1.0, 1.0)) * (2.0 if index != 1 else 0.25)
        rows.append(row)
    return rows, onset


def generate_synthetic_sequences(
    count: int = 100,
    sequence_length: int | None = None,
    seed: int = 42,
    scenario: str | None = None,
) -> Iterator[tuple[list[list[float | None]], int]]:
    """Yield (records, noisy onset label) with overlapping scenario classes."""
    length = sequence_length or AI_CONFIG.simulator_length
    rng = random.Random(seed)
    for _ in range(count):
        chosen = scenario or rng.choice(SCENARIOS)
        if chosen not in SCENARIOS:
            raise ValueError(f"unknown synthetic scenario: {chosen}")
        records, onset = _simulate(chosen, length, rng)
        label = int(onset is not None and length - AI_CONFIG.horizon <= onset < length)
        if rng.random() < AI_CONFIG.label_noise:
            label = 1 - label
        yield records, label


def records_to_dicts(records: list[list[float | None]]) -> list[dict[str, float | None]]:
    return [dict(zip(FEATURE_NAMES, row)) for row in records]
