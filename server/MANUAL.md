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

- `POST /api/admin/devices` registers a device. Requires `X-Admin-Key`; accepts `device_id`, `name`, and optional `device_key`. The admin response includes the key, and `GET /api/admin/devices` can retrieve it for this small operations team.
- `GET /api/devices` lists registered devices without keys.
- `POST /api/readings` accepts sensor fields and requires `X-Device-Key`. Devices must already be registered.
- `GET /api/readings?device_id=...&limit=...` and `GET /api/readings/latest?device_id=...` are public.
- `POST /api/predict` accepts `device_id` and optionally readings. Stored readings are queried only for that device before LSTM/BOCPD fusion.
- `GET /api/health` reports service status and storage dialect.

Timestamps are generated in `Asia/Manila` with `YYYY-MM-DD HH:MM:SS` formatting. The shipped checkpoint is trained on synthetic data and is for development only.