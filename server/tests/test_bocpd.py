import math

from app.bocpd import BOCPD


def test_stationary_series_stays_low_after_warmup() -> None:
    detector = BOCPD(hazard=0.02, warmup=8)
    values = [detector.update((0.0, 0.0, 0.0)) for _ in range(30)]
    assert max(values[8:]) < 0.8


def test_mean_shift_raises_short_run_score() -> None:
    detector = BOCPD(hazard=0.03, warmup=5)
    for _ in range(25):
        detector.update((0.0, 0.0, 0.0))
    scores = [detector.update((4.0, 4.0, -4.0)) for _ in range(8)]
    assert max(scores) > 0.2


def test_bocpd_is_bounded_and_safe_for_constant_nan_input() -> None:
    detector = BOCPD()
    scores = [detector.update((math.nan, 1.0, 1.0)) for _ in range(20)]
    assert all(0.0 <= value <= 1.0 for value in scores)
    detector.reset()
    assert detector.get_change_probability() == 0.0
