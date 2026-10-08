import pytest

from app.prediction import PredictionService


def test_prediction_weights_are_validated() -> None:
    with pytest.raises(ValueError):
        PredictionService("missing.pt", 0.8, 0.8, 20)


def test_prediction_service_contract_keys(monkeypatch) -> None:
    service = PredictionService("missing.pt", 0.7, 0.3, 2)
    service.model = lambda _inputs: None
    service.preprocessor = service.preprocessor.__class__(2, (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
    class FakeModel:
        def __call__(self, _inputs):
            return __import__("torch").tensor([0.25])
    service.model = FakeModel()
    output = service.predict([
        {"temperature": 27.0, "ph": 7.2, "dissolved_oxygen": 5.5},
        {"temperature": 27.0, "ph": 7.2, "dissolved_oxygen": 5.5},
    ])
    assert set(output) == {"lstm_probability", "bocpd_probability", "risk_score", "synthetic_model_notice"}
    assert output["synthetic_model_notice"]
