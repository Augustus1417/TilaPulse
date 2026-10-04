# TilaPulse Backend Manual

The backend is a long-running FastAPI/ASGI service. It uses SQLAlchemy storage configured through `DATABASE_URL`, supports SQLite for local development and PostgreSQL deployments, and loads the LSTM checkpoint once during startup.

## Configuration

Copy `.env.example` to `.env` and set `DATABASE_URL` to the Supabase connection string and `ADMIN_API_KEY` to a private operations secret. The older `DB_CONNECTION_STRING` name is accepted as a compatibility alias, but new deployments should use `DATABASE_URL`.

Run locally from `server`:

```text
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

For Render, Railway, or Fly.io, use `uvicorn app.main:app --host 0.0.0.0 --port $PORT` as the start command and define the two secrets in the platform environment.

## Routes

- `POST /api/admin/devices` registers a device. Requires `X-Admin-Key`; accepts `device_id`, `name`, and optional `device_key`. The response returns the raw key once and marks it non-retrievable afterward. `GET /api/admin/devices` never returns keys or hashes.
- `GET /api/devices` lists registered devices without keys.
- `POST /api/devices/connect` accepts `device_id` and `device_key`, then returns an opaque bearer session token. Failed attempts return a generic error and are rate-limited.
- `DELETE /api/devices/disconnect` revokes the current bearer session.
- `GET /api/devices/{device_id}/command` accepts `X-Device-Key`, updates `last_seen`, and returns the current `reading_enabled` state for firmware polling.
- `PATCH /api/devices/{device_id}/reading-state` updates `reading_enabled` for the device associated with the bearer session.
- `POST /api/readings` accepts sensor fields and requires `X-Device-Key`. Devices must already be registered.
- `GET /api/readings?device_id=...&limit=...` and `GET /api/readings/latest?device_id=...` require a bearer token for the same device.
- `GET /api/devices/{device_id}/alerts` lists active threshold alerts and `DELETE /api/devices/{device_id}/alerts/{alert_id}` resolves one.
- `POST /api/devices/{device_id}/predict` explicitly runs LSTM/BOCPD fusion once for the device's stored readings, persists the assessment, and requires a bearer token for the same device.
- `GET /api/devices/{device_id}/risk/latest` returns the latest stored assessment without recomputing it; it returns `404` until the first explicit assessment.
- `GET /api/devices/{device_id}/risk/history?limit=...` returns stored assessments newest-first for the device.
- `POST /api/admin/devices/{device_id}/rotate-key` requires `X-Admin-Key`, returns a new raw key once, and immediately revokes every session for that device.
- `GET /api/health` reports service status and storage dialect.

Timestamps are generated in `Asia/Manila` with `YYYY-MM-DD HH:MM:SS` formatting. The shipped checkpoint is trained on synthetic data and is for development only.

## Reading Control

The app can pause or resume a device through `PATCH /api/devices/{device_id}/reading-state`:

```json
{"enabled": false}
```

The firmware currently posts readings but does not yet poll `/api/devices/{device_id}/command`, so changing this state is persisted and visible through the API but is not enforced on the ESP32.

## Alerts

Readings create one active alert per device and parameter when they breach the configured healthy ranges. Current thresholds are temperature below `24 C` or above `32 C`, pH below `6.5` or above `8.5`, and dissolved oxygen below `5 mg/L`. Resolving an alert deletes the active record; a later breach can create a new alert.

## Development Limitations

The included LSTM checkpoint and training script use synthetic sequences only. The prediction code is suitable for software development and API integration, but a production deployment still requires labelled farm data, model evaluation, and hardware validation. Flutter and firmware integration are not covered by automated tests in this repository.