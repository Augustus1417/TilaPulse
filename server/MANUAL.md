# TilaPulse Backend Manual

The backend is a long-running FastAPI/ASGI service. It uses Supabase PostgreSQL through SQLAlchemy and loads the LSTM checkpoint once during startup.

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
- `POST /api/readings` accepts sensor fields and requires `X-Device-Key`. Devices must already be registered.
- `GET /api/readings?device_id=...&limit=...` and `GET /api/readings/latest?device_id=...` require a bearer token for the same device.
- `POST /api/devices/{device_id}/predict` explicitly runs LSTM/BOCPD fusion once for the device's stored readings, persists the assessment, and requires a bearer token for the same device.
- `GET /api/devices/{device_id}/risk/latest` returns the latest stored assessment without recomputing it; it returns `404` until the first explicit assessment.
- `GET /api/devices/{device_id}/risk/history?limit=...` returns stored assessments newest-first for the device.
- `POST /api/admin/devices/{device_id}/rotate-key` requires `X-Admin-Key`, returns a new raw key once, and immediately revokes every session for that device.
- `GET /api/health` reports service status and storage dialect.

Timestamps are generated in `Asia/Manila` with `YYYY-MM-DD HH:MM:SS` formatting. The shipped checkpoint is trained on synthetic data and is for development only.