from app.preprocessing import SensorPreprocessor


def test_fit_window_shape_and_missing_values() -> None:
    train = [[
        {"temperature": 27.0, "ph": 7.2, "dissolved_oxygen": 5.5},
        {"temperature": None, "ph": 7.3, "dissolved_oxygen": 5.4},
    ]]
    processor = SensorPreprocessor(window_size=4).fit(train)
    result = processor.window(train[0])
    assert len(result) == 4
    assert all(len(row) == 3 for row in result)
    assert all(value == value for row in result for value in row)


def test_serialized_scaler_matches_inference_path() -> None:
    records = [{"temperature": 27.0, "ph": 7.2, "dissolved_oxygen": 5.5}]
    processor = SensorPreprocessor(window_size=2).fit([records])
    restored = SensorPreprocessor.from_dict(processor.to_dict(), 2)
    assert restored.window(records) == processor.window(records)
