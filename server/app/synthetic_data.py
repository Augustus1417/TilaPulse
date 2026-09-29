import random
from collections.abc import Iterator


def generate_synthetic_sequences(count: int = 100, sequence_length: int = 20, seed: int = 42) -> Iterator[tuple[list[list[float]], int]]:
    """Generate development-only sequences for training the placeholder checkpoint."""
    generator = random.Random(seed)
    for _ in range(count):
        state = [28.0, 7.2, 5.5]
        mode = generator.choice(("normal", "deterioration", "sudden", "recovery"))
        sequence = []
        for step in range(sequence_length):
            if mode == "deterioration":
                state[0] += 0.05
                state[1] -= 0.012
                state[2] -= 0.04
            elif mode == "sudden" and step >= sequence_length // 2:
                state[0] += 0.5
                state[1] -= 0.12
                state[2] -= 0.35
            elif mode == "recovery":
                state = [value + (target - value) * 0.08 for value, target in zip(state, (28.0, 7.2, 5.5))]
            state = [value + generator.gauss(0, noise) for value, noise in zip(state, (0.08, 0.015, 0.06))]
            sequence.append(state[:])
        yield sequence, int(mode in ("deterioration", "sudden"))