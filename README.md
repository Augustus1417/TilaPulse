# TilaPulse

TilaPulse is a tilapia pond monitoring prototype. An ESP32 samples water
quality sensors and sends readings to a FastAPI backend. A Flutter client
shows current conditions, trends, alerts, and model-based risk assessments.

The project currently supports:

- Temperature, pH, and dissolved oxygen readings
- Device registration, device-key authentication, and device-scoped sessions
- Live reading history and bucketed trend data for 1 hour, 24 hours, 7 days,
  and 30 days
- Healthy-range alerts for temperature, pH, and dissolved oxygen
- Remote pause/resume of ESP32 sampling
- LSTM and BOCPD risk assessments with persisted history
- Android Firebase Cloud Messaging notifications for alerts, high risk, and
  offline devices
- Wi-Fi provisioning through the ESP32's WiFiManager setup portal

The system is a development prototype. The included AI model is trained and
evaluated on synthetic data only and must not be treated as evidence of real
fish-disease prediction or field performance.

## Architecture

```text
ESP32 sensors
  -> authenticated POST /api/readings
  -> FastAPI validation and SQLAlchemy storage
  -> Flutter client authenticated with a device session
  -> readings, trends, alerts, and risk pages

Flutter client
  -> POST /api/devices/{device_id}/predict
  -> LSTM probability + BOCPD change-point probability
  -> persisted weighted risk assessment
  -> optional Android FCM notification
```

## Repository layout

```text
tilapulse_device.ino       ESP32 firmware

client/                     Flutter application
  lib/pages/                Home, monitor, risk, alerts, settings, and device pages
  lib/services/api_service.dart
                            API client and device-session handling
  lib/services/notification_service.dart
                            Firebase Messaging and local notification handling
  lib/state/device_state.dart
                            Connected-device state
  test/                     Flutter widget tests

server/                     FastAPI backend
  app/                      API, persistence, prediction, alerts, and notifications
  models/lstm_model.pt      Development checkpoint
  scripts/                  Synthetic training and evaluation scripts
  tests/                    Backend tests
  MANUAL.md                 Backend deployment and configuration reference
```

## Backend

The backend uses FastAPI, SQLAlchemy, and Pydantic. SQLite works for local
development; production deployments should use PostgreSQL, such as Supabase.
The default hosted API used by the firmware and Flutter client is:

```text
https://tilapulse.onrender.com
```

### Local setup

From `server`:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

For an ESP32 on the same network, bind the server to the computer's LAN
interfaces:

```powershell
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The local API is then available at `http://localhost:8000`. Swagger UI is
available at `/docs`, the OpenAPI document at `/openapi.json`, and the health
check at `/api/health`.

Create `server/.env` with at least:

```env
DATABASE_URL=sqlite:///./tilapulse.db
ADMIN_API_KEY=replace-with-a-long-admin-secret
PREDICTION_ALPHA=0.7
PREDICTION_BETA=0.3
PREDICTION_WINDOW_SIZE=20
PREDICTION_INTERVAL_MINUTES=60
PREDICTION_MIN_READINGS=20
SCHEDULER_ENABLED=true
```

`DB_CONNECTION_STRING` is accepted as a compatibility alias for
`DATABASE_URL`. See [`server/MANUAL.md`](server/MANUAL.md) for Render,
PostgreSQL, CORS, scheduler, and Firebase configuration.

Run the backend tests from `server`:

```powershell
python -m pytest -q
```

### API routes

| Method | Route | Purpose |
| --- | --- | --- |
| `GET` | `/` | Basic API information |
| `GET` | `/api/health` | Service and database health |
| `POST` | `/api/admin/devices` | Register a device; requires `X-Admin-Key` |
| `GET` | `/api/devices` | List registered devices |
| `POST` | `/api/devices/connect` | Exchange a device ID/key for a bearer session |
| `DELETE` | `/api/devices/disconnect` | Revoke the current session |
| `PATCH` | `/api/devices/{device_id}/name` | Rename an authenticated device |
| `GET` | `/api/devices/{device_id}/command` | Firmware heartbeat and reading state |
| `PATCH` | `/api/devices/{device_id}/reading-state` | Pause or resume device readings |
| `POST` | `/api/readings` | Store one reading; requires `X-Device-Key` |
| `GET` | `/api/readings` | Read authenticated device history |
| `GET` | `/api/readings/latest` | Read the latest authenticated reading |
| `GET` | `/api/readings/series` | Return bucketed sensor summaries |
| `POST` | `/api/devices/{device_id}/predict` | Run and persist an assessment |
| `GET` | `/api/devices/{device_id}/risk/latest` | Return the latest assessment |
| `GET` | `/api/devices/{device_id}/risk/history` | Return assessment history |
| `GET` | `/api/devices/{device_id}/alerts` | List active threshold alerts |
| `DELETE` | `/api/devices/{device_id}/alerts/{alert_id}` | Resolve an alert |
| `POST` | `/api/devices/{device_id}/push-token` | Register an Android FCM token |
| `DELETE` | `/api/devices/{device_id}/push-token` | Remove the current session's token |
| `POST` | `/api/devices/{device_id}/push-test` | Send a rate-limited test notification |
| `POST` | `/api/admin/devices/{device_id}/rotate-key` | Rotate a key and revoke sessions |

### Register and connect a device

Register a device with the administrator key. The raw device key is returned
only once:

```powershell
curl.exe -X POST http://localhost:8000/api/admin/devices `
  -H "X-Admin-Key: replace-with-a-long-admin-secret" `
  -H "Content-Type: application/json" `
  -d '{"device_id":"pond-1","name":"Pond 1","device_key":"replace-with-a-private-device-key"}'
```

Exchange the device credentials for the bearer token used by client routes:

```powershell
curl.exe -X POST http://localhost:8000/api/devices/connect `
  -H "Content-Type: application/json" `
  -d '{"device_id":"pond-1","device_key":"replace-with-a-private-device-key"}'
```

The token is device-scoped. The client stores it in secure storage, and the
backend never returns stored device keys or key hashes.

## ESP32 firmware

The firmware in [`tilapulse_device.ino`](tilapulse_device.ino) currently:

- Uses WiFiManager to provision Wi-Fi through a device-specific setup AP
- Reads a DS18B20 temperature sensor, analog pH sensor, and analog dissolved
  oxygen sensor
- Posts an authenticated reading every two seconds
- Polls the command endpoint every five seconds as a heartbeat
- Applies the server's `reading_enabled` state to pause or resume sampling
- Reconnects to Wi-Fi and supports a boot-time reset pin for saved credentials

Before flashing, set `API_BASE_URL`, `DEVICE_ID`, and `DEVICE_KEY` to values
for a registered device. The device key is a secret and should not be
committed. Install the firmware's Arduino dependencies (WiFiManager,
ArduinoJson, OneWire, and DallasTemperature) through the Arduino library
manager.

For a local backend, use the computer's LAN address in `API_BASE_URL`; an
ESP32 cannot reach the host computer through `localhost`.

## Flutter client

From `client`:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

The API URL can be changed at build or run time with `--dart-define`. For the
Android emulator, use `http://10.0.2.2:8000`; for a physical phone, use the
computer's LAN address. Without an override, the client uses the hosted API
URL shown above.

The app's tabs are:

- **Home**: current reading, health indicators, and latest risk summary
- **Monitor**: recent readings, trend charts, and selectable time ranges
- **Risk**: run an assessment and view risk history
- **Alerts**: review and resolve active threshold alerts
- **Settings**: connect, rename, pause/resume, and manage devices

Android notifications use Firebase Cloud Messaging and local notification
channels. The backend sends notifications for configured pond alerts, high
risk assessments, and devices that have been offline for the configured
period. Configure Firebase credentials and push settings on the backend as
described in [`server/MANUAL.md`](server/MANUAL.md).

Run Flutter tests from `client`:

```powershell
flutter test
```

## Risk and alert behavior

The current configured healthy ranges are:

- Temperature: `24 C` through `32 C`
- pH: `6.5` through `8.5`
- Dissolved oxygen: at least `5 mg/L`

The prediction pipeline fills missing values, normalizes the three sensor
features, and creates a fixed 20-reading window. The LSTM and BOCPD outputs
are combined by default as:

```text
risk_score = 0.7 * lstm_probability + 0.3 * bocpd_change_point_probability
```

The scheduler can run assessments periodically when enabled and enough
readings are available. The included model checkpoint and synthetic training
data are for development and API integration only. A production system
requires labelled farm data, evaluation against real outcomes, and hardware
validation.

## Synthetic model training

From `server`:

```powershell
python scripts/train_lstm.py
python scripts/evaluate.py
```

The generated sequences represent normal conditions, gradual deterioration,
sudden changes, and recovery. Their metrics describe the synthetic pipeline,
not real-world disease performance.

## Security notes

- Keep `ADMIN_API_KEY`, device keys, bearer tokens, and Firebase credentials
  private.
- Do not commit Firebase service-account JSON files or production `.env` files.
- Use HTTPS for deployed API traffic.
- Use PostgreSQL or another managed database in production; hosted Render
  filesystems are ephemeral.
