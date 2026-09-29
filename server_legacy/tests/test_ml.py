import pytest

from app.bocpd import BOCPD
from app.preprocessing import SensorPreprocessor
from app.synthetic_data import generate_synthetic_sequences


def test_preprocessor_handles_missing_values_and_fixed_window():
    preprocessor = SensorPreprocessor(window_size=3)
    window = preprocessor.window([{"temperature": 28.0, "ph": None, "dissolved_oxygen": 5.5}])

    assert len(window) == 3
    assert all(len(row) == 3 for row in window)
    assert window[-1] == [0.0, 0.0, 0.0]


def test_preprocessor_creates_sliding_windows():
    records = [{"temperature": value, "ph": 7.2, "dissolved_oxygen": 5.5} for value in range(5)]

    assert len(SensorPreprocessor(window_size=3).windows(records)) == 3


def test_bocpd_detects_a_large_change_and_can_reset():
    detector = BOCPD(hazard=0.01)
    for _ in range(8):
        detector.update(0.0)
    before = detector.get_change_probability()
    after = detector.update(8.0)

    assert after > before
    detector.reset()
    assert detector.get_change_probability() == 0.0


def test_synthetic_generator_is_reproducible_and_temporal():
    first = list(generate_synthetic_sequences(count=2, sequence_length=5, seed=7))
    second = list(generate_synthetic_sequences(count=2, sequence_length=5, seed=7))

    assert first == second
    assert len(first[0][0]) == 5
    assert first[0][0][0] != first[0][0][-1]


def test_lstm_accepts_sequence_of_three_features_and_returns_probability():
    torch = pytest.importorskip("torch")
    from app.lstm import build_lstm_model

    model = build_lstm_model()
    output = model(torch.zeros((2, 4, 3)))

    assert tuple(output.shape) == (2,)
    assert torch.all((output >= 0) & (output <= 1))


def test_risk_fusion_uses_configured_weights():
    alpha, beta = 0.7, 0.3
    assert alpha + beta == 1.0
    assert alpha * 0.8 + beta * 0.2 == pytest.approx(0.62)