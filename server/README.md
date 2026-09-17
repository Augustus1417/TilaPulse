# TilaPulse Sensor API

A small FastAPI backend for receiving sensor readings from a future ESP32 and serving them to the Flutter app. The current version uses bounded in-memory storage only. It does not use a database or MQTT. Its optional ML prototype combines a PyTorch LSTM with BOCPD.

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

Submit a sensor reading. The backend adds a Philippine local timestamp:

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

Example response:

```json
{
  "device_id": "ESP32-TILAPIA-001",
  "temperature": 28.4,
  "ph": 7.2,
  "dissolved_oxygen": 5.8,
  "timestamp": "2026-09-17 13:45:32"
}
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

## ML prototype

Train the development-only synthetic model from this directory:

```bash
python scripts/train_lstm.py
```

Synthetic data contains temporal patterns for software development only. It does not represent real tilapia disease observations or establish model accuracy. The final model must be trained and evaluated with appropriate labelled farm/BFAR data using Accuracy, Precision, Recall, F1-score, and ROC-AUC.

Predict from a sensor sequence:

```bash
curl -X POST http://localhost:8000/api/predict -H "Content-Type: application/json" -d '{
  "readings": [
    {"device_id": "ESP32-TILAPIA-001", "temperature": 29.5, "ph": 7.2, "dissolved_oxygen": 5.8}
  ]
}'
```

The response contains `lstm_probability`, `bocpd_probability`, and a configurable weighted `risk_score`. Before training, this endpoint returns HTTP 503 with instructions instead of crashing.

Example response after a model has been trained:

```json
{
  "lstm_probability": 0.72,
  "bocpd_probability": 0.61,
  "risk_score": 0.687,
  "synthetic_model_notice": "A checkpoint trained on SYNTHETIC data is for software development only, not real disease evidence."
}
```

## Flutter integration

The Flutter app can use Dart's `http` package to call these JSON endpoints. For Android emulator development, the host machine is usually `http://10.0.2.2:8000`; for a physical phone, use the computer's LAN IP. The response field names are stable and match the sensor contract:

`device_id`, `temperature`, `ph`, `dissolved_oxygen`, `timestamp`

CORS allows common localhost development origins and can be extended through the `CORS_ORIGINS` environment setting when needed.

## Tests

```bash
pytest
```
