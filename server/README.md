# TilaPulse Sensor API

A small FastAPI backend for receiving tilapia aquaculture sensor readings from a future ESP32 and serving them to the Flutter app. The current version uses bounded in-memory storage only. It does not use a database, MQTT, authentication, or ML predictions.

## Installation

From this `server` directory:

```bash
python -m venv .venv
# Windows PowerShell
.venv\Scripts\Activate.ps1
# macOS/Linux
# source .venv/bin/activate
pip install -r requirements.txt
```

## Run the server

```bash
uvicorn app.main:app --reload
```

The API is available at `http://localhost:8000`. Swagger documentation is at `http://localhost:8000/docs`, with the OpenAPI schema at `http://localhost:8000/openapi.json`.

## API examples

Health check:

```bash
curl http://localhost:8000/api/health
```

Submit a sensor reading. The backend adds the UTC timestamp:

```bash
curl -X POST http://localhost:8000/api/readings \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "ESP32-TILAPIA-001",
    "temperature": 28.4,
    "ph": 7.2,
    "dissolved_oxygen": 5.8
  }'
```

Get the latest reading for a device:

```bash
curl "http://localhost:8000/api/readings/latest?device_id=ESP32-TILAPIA-001"
```

Get recent readings, newest first:

```bash
curl "http://localhost:8000/api/readings?device_id=ESP32-TILAPIA-001&limit=20"
```

List devices that have submitted readings:

```bash
curl http://localhost:8000/api/devices
```

Generate one realistic mock reading:

```bash
curl -X POST "http://localhost:8000/api/mock/generate?device_id=ESP32-TILAPIA-001"
```

Generate 100 simulated historical readings:

```bash
curl -X POST "http://localhost:8000/api/mock/generate-batch?count=100&device_id=ESP32-TILAPIA-001"
```

Mock readings use gradual sensor drift, small fluctuations, and occasional outliers. At most 1,000 readings are retained in memory; restarting the server clears them.

## Flutter integration

The Flutter app can use Dart's `http` package to call these JSON endpoints. For Android emulator development, the host machine is usually `http://10.0.2.2:8000`; for a physical phone, use the computer's LAN IP. The response field names are stable and match the sensor contract:

`device_id`, `temperature`, `ph`, `dissolved_oxygen`, `timestamp`

CORS allows common localhost development origins and can be extended through the `CORS_ORIGINS` environment setting when needed.

## Tests

```bash
pytest
```
