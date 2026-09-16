from datetime import datetime, timedelta, timezone
import random

from app.schemas.sensor_reading import SensorReadingCreate


DEFAULT_DEVICE_ID = "ESP32-TILAPIA-001"


class MockSensor:
    def __init__(self) -> None:
        self._random_by_device: dict[str, random.Random] = {}
        self._state_by_device: dict[str, list[float]] = {}

    def _get_random(self, device_id: str) -> random.Random:
        if device_id not in self._random_by_device:
            seed = sum((index + 1) * ord(character) for index, character in enumerate(device_id))
            self._random_by_device[device_id] = random.Random(seed)
        return self._random_by_device[device_id]

    def generate(self, device_id: str = DEFAULT_DEVICE_ID) -> SensorReadingCreate:
        generator = self._get_random(device_id)
        state = self._state_by_device.setdefault(device_id, [28.0, 7.2, 5.5])

        for index, step in enumerate((0.18, 0.035, 0.12)):
            state[index] += generator.uniform(-step, step)

        if generator.random() < 0.04:
            sensor_index = generator.randrange(3)
            state[sensor_index] += generator.choice((-1, 1)) * (2.5 if sensor_index == 0 else 1.2)

        return SensorReadingCreate(
            device_id=device_id,
            temperature=round(state[0] + generator.uniform(-0.08, 0.08), 2),
            ph=round(state[1] + generator.uniform(-0.02, 0.02), 2),
            dissolved_oxygen=round(max(0, state[2] + generator.uniform(-0.08, 0.08)), 2),
        )

    def generate_batch(self, device_id: str, count: int) -> list[tuple[SensorReadingCreate, datetime]]:
        start = datetime.now(timezone.utc) - timedelta(minutes=count - 1)
        return [
            (self.generate(device_id), start + timedelta(minutes=index))
            for index in range(count)
        ]


mock_sensor = MockSensor()
