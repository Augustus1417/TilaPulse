from collections.abc import Mapping
from datetime import datetime, timedelta, timezone
from typing import Literal
from typing import Any
from zoneinfo import ZoneInfo

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException, Query, Request, status
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.alerts import evaluate_reading_alerts
from app.core.config import DO_MIN_MGL, PH_MAX, PH_MIN, TEMP_MAX_C, TEMP_MIN_C, settings
from app.core.rate_limit import limiter
from app.core.security import verify_ingestion_device_key, verify_device_session
from app.db import get_db
from app.models import DeviceModel, ReadingModel
from app.notifications import notify_alerts
from app.schemas import ReadingIn, ReadingOut, ReadingSeriesOut


router = APIRouter(prefix="/api/readings", tags=["readings"])


def now_local() -> str:
    return datetime.now(ZoneInfo(settings.timezone)).strftime("%Y-%m-%d %H:%M:%S")


def to_reading_out(reading: ReadingModel) -> ReadingOut:
    return ReadingOut(
        device_id=reading.device_id,
        temperature=reading.temperature,
        ph=reading.ph,
        dissolved_oxygen=reading.dissolved_oxygen,
        timestamp=reading.timestamp,
    )


@router.post("", response_model=ReadingOut, status_code=status.HTTP_201_CREATED)
def create_reading(
    payload: ReadingIn,
    background_tasks: BackgroundTasks,
    x_device_key: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> ReadingOut:
    device = db.get(DeviceModel, payload.device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device is not registered")
    verify_ingestion_device_key(device.device_key_hash, x_device_key)

    timestamp = now_local()
    device.last_seen = timestamp
    reading = ReadingModel(
        device_id=payload.device_id,
        temperature=payload.temperature,
        ph=payload.ph,
        dissolved_oxygen=payload.dissolved_oxygen,
        timestamp=timestamp,
    )
    db.add(reading)
    db.commit()
    db.refresh(reading)
    created_alerts = evaluate_reading_alerts(reading, db)
    db.commit()
    if created_alerts:
        background_tasks.add_task(notify_alerts, payload.device_id, [alert.id for alert in created_alerts])
    return to_reading_out(reading)


@router.get("", response_model=list[ReadingOut])
def list_readings(
    device_id: str = Query(min_length=1),
    limit: int = Query(default=100, ge=1, le=1000),
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> list[ReadingOut]:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    readings = db.scalars(
        select(ReadingModel)
        .where(ReadingModel.device_id == device_id)
        .order_by(ReadingModel.id.desc())
        .limit(limit)
    ).all()
    return [to_reading_out(reading) for reading in reversed(readings)]


@router.get("/series", response_model=ReadingSeriesOut)
@limiter.limit("60/minute")
def reading_series(
    request: Request,
    device_id: str = Query(min_length=1),
    range: Literal["1h", "24h", "7d", "30d"] = Query(default="24h"),
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> ReadingSeriesOut:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")

    range_config = {
        "1h": (timedelta(hours=1), 60),
        "24h": (timedelta(hours=24), 900),
        "7d": (timedelta(days=7), 3600),
        "30d": (timedelta(days=30), 21600),
    }
    window, bucket_seconds = range_config[range]
    to_time = datetime.now(timezone.utc).replace(microsecond=0)
    from_time = to_time - window
    params = {
        "device_id": device_id,
        "from_timestamp": from_time.strftime("%Y-%m-%d %H:%M:%S"),
        "to_timestamp": to_time.strftime("%Y-%m-%d %H:%M:%S"),
        "bucket_seconds": bucket_seconds,
        "source_timezone": settings.timezone,
    }

    if db.bind is not None and db.bind.dialect.name == "postgresql":
        bucket_expression = (
            "floor(extract(epoch from "
            "(cast(timestamp as timestamp) AT TIME ZONE :source_timezone)) / :bucket_seconds) "
            "* :bucket_seconds"
        )
        timestamp_expression = "cast(timestamp as timestamp) AT TIME ZONE :source_timezone"
        from_bound = "CAST(:from_timestamp AS timestamp) AT TIME ZONE 'UTC'"
        to_bound = "CAST(:to_timestamp AS timestamp) AT TIME ZONE 'UTC'"
        rounded_aggregate = lambda expression: f"round(({expression})::numeric, 2)::double precision"
    else:
        offset = datetime.now(ZoneInfo(settings.timezone)).utcoffset()
        offset_hours = int(offset.total_seconds() // 3600) if offset is not None else 0
        utc_modifier = f"{-offset_hours:+d} hours"
        bucket_expression = (
            "floor(cast(strftime('%s', datetime(timestamp, "
            f"'{utc_modifier}')) as float) / :bucket_seconds) "
            "* :bucket_seconds"
        )
        timestamp_expression = f"datetime(timestamp, '{utc_modifier}')"
        from_bound = ":from_timestamp"
        to_bound = ":to_timestamp"
        rounded_aggregate = lambda expression: f"round({expression}, 2)"

    rows = db.execute(
        text(
            f"""
            SELECT
                {bucket_expression} AS bucket_epoch,
                count(*) AS reading_count,
                {rounded_aggregate("avg(temperature)")} AS temperature_avg,
                {rounded_aggregate("min(temperature)")} AS temperature_min,
                {rounded_aggregate("max(temperature)")} AS temperature_max,
                {rounded_aggregate("avg(ph)")} AS ph_avg,
                {rounded_aggregate("min(ph)")} AS ph_min,
                {rounded_aggregate("max(ph)")} AS ph_max,
                {rounded_aggregate("avg(dissolved_oxygen)")} AS dissolved_oxygen_avg,
                {rounded_aggregate("min(dissolved_oxygen)")} AS dissolved_oxygen_min,
                {rounded_aggregate("max(dissolved_oxygen)")} AS dissolved_oxygen_max
            FROM readings
            WHERE device_id = :device_id
              AND {timestamp_expression} >= {from_bound}
              AND {timestamp_expression} <= {to_bound}
            GROUP BY bucket_epoch
            ORDER BY bucket_epoch ASC
            """
        ),
        params,
    ).mappings().all()

    def metric(row: Mapping[str, Any], prefix: str) -> dict[str, float]:
        values = row
        return {
            "avg": float(values[f"{prefix}_avg"]),
            "min": float(values[f"{prefix}_min"]),
            "max": float(values[f"{prefix}_max"]),
        }

    return ReadingSeriesOut(
        device_id=device_id,
        range=range,
        bucket_seconds=bucket_seconds,
        from_=from_time.isoformat().replace("+00:00", "Z"),
        to=to_time.isoformat().replace("+00:00", "Z"),
        points=[
            {
                "t": datetime.fromtimestamp(float(row["bucket_epoch"]), timezone.utc)
                .isoformat()
                .replace("+00:00", "Z"),
                "count": int(row["reading_count"]),
                "temperature": metric(row, "temperature"),
                "ph": metric(row, "ph"),
                "dissolved_oxygen": metric(row, "dissolved_oxygen"),
            }
            for row in rows
        ],
        thresholds={
            "temperature": {"min": TEMP_MIN_C, "max": TEMP_MAX_C},
            "ph": {"min": PH_MIN, "max": PH_MAX},
            "dissolved_oxygen": {"min": DO_MIN_MGL, "max": None},
        },
    )


@router.get("/latest", response_model=ReadingOut)
def latest_reading(
    device_id: str = Query(min_length=1),
    session_device_id: str = Depends(verify_device_session),
    db: Session = Depends(get_db),
) -> ReadingOut:
    if device_id != session_device_id:
        raise HTTPException(status_code=403, detail="Session is not authorized for this device")
    reading = db.scalar(
        select(ReadingModel)
        .where(ReadingModel.device_id == device_id)
        .order_by(ReadingModel.id.desc())
    )
    if reading is None:
        raise HTTPException(status_code=404, detail="No readings found for device")
    return to_reading_out(reading)