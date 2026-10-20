import logging
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from fastapi import FastAPI
from sqlalchemy import func, select

from app.core.config import settings
from app.db import SessionLocal
from app.models import DeviceModel, PredictionModel, ReadingModel
from app.notifications import submit_notification
from app.prediction_runner import run_prediction
from app.routers.devices import is_device_online


logger = logging.getLogger(__name__)


def _is_recent(prediction: PredictionModel, now: datetime) -> bool:
    created_at = datetime.strptime(prediction.created_at, "%Y-%m-%d %H:%M:%S").replace(
        tzinfo=ZoneInfo(settings.timezone)
    )
    return created_at > now - timedelta(minutes=settings.prediction_interval_minutes * 0.9)


def run_scheduled_predictions(app: FastAPI) -> None:
    """Run one isolated scheduled assessment pass for every registered device."""
    for device_id in _device_ids():
        try:
            with SessionLocal() as db:
                device = db.get(DeviceModel, device_id)
                if device is None:
                    continue
                if not device.reading_enabled:
                    logger.info("Skipping scheduled prediction for %s: reading disabled", device_id)
                    continue
                if not is_device_online(device):
                    logger.info("Skipping scheduled prediction for %s: device offline", device_id)
                    continue
                reading_count = db.scalar(
                    select(func.count(ReadingModel.id)).where(ReadingModel.device_id == device_id)
                ) or 0
                if reading_count < settings.prediction_min_readings:
                    logger.info(
                        "Skipping scheduled prediction for %s: only %s readings",
                        device_id,
                        reading_count,
                    )
                    continue
                latest_reading = db.scalar(
                    select(ReadingModel)
                    .where(ReadingModel.device_id == device_id)
                    .order_by(ReadingModel.id.desc())
                )
                latest_prediction = db.scalar(
                    select(PredictionModel)
                    .where(PredictionModel.device_id == device_id)
                    .order_by(PredictionModel.id.desc())
                )
                if latest_prediction is not None:
                    if latest_reading is not None and latest_reading.timestamp <= latest_prediction.created_at:
                        logger.info(
                            "Skipping scheduled prediction for %s: no new reading",
                            device_id,
                        )
                        continue
                    if _is_recent(latest_prediction, datetime.now(ZoneInfo(settings.timezone))):
                        logger.info(
                            "Skipping scheduled prediction for %s: prediction is too recent",
                            device_id,
                        )
                        continue
                run_prediction(db, device_id, "scheduled", app.state.prediction_service)
        except Exception:
            logger.exception("Scheduled prediction failed for device %s", device_id)


def run_offline_notifications() -> None:
    """Notify once when a previously seen device has remained offline."""
    now = datetime.now(ZoneInfo(settings.timezone))
    try:
        with SessionLocal() as db:
            devices = db.scalars(select(DeviceModel)).all()
            for device in devices:
                if is_device_online(device):
                    device.offline_notified = False
                    continue
                if device.last_seen is None or device.offline_notified:
                    continue
                last_seen = datetime.strptime(device.last_seen, "%Y-%m-%d %H:%M:%S").replace(
                    tzinfo=ZoneInfo(settings.timezone)
                )
                minutes_offline = int((now - last_seen).total_seconds() // 60)
                if minutes_offline >= settings.offline_notify_after_minutes:
                    submit_notification(
                        device.device_id,
                        f"{device.name} is offline",
                        f"No data received for {minutes_offline} minutes. Check power and WiFi.",
                        {"type": "device_offline", "device_id": device.device_id},
                        "offline",
                    )
                    device.offline_notified = True
            db.commit()
    except Exception:
        logger.exception("Offline notification job failed")


def _device_ids() -> list[str]:
    with SessionLocal() as db:
        return list(db.scalars(select(DeviceModel.device_id)).all())
