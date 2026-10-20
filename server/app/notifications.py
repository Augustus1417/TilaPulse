import json
import logging
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select

from app.core.config import settings
from app.db import SessionLocal
from app.models import AlertModel, DeviceModel, DeviceSessionModel, NotificationLogModel, PushTokenModel

logger = logging.getLogger(__name__)
_executor = ThreadPoolExecutor(max_workers=4)
_firebase_messaging = None
_firebase_ready = False

try:
    if settings.push_enabled:
        import firebase_admin
        from firebase_admin import credentials, messaging

        credential_value = settings.firebase_credentials_json
        credential_path = settings.google_application_credentials
        if credential_value:
            credential = credentials.Certificate(json.loads(credential_value))
        elif credential_path:
            credential = credentials.Certificate(credential_path)
        else:
            raise RuntimeError("No Firebase credentials configured")
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credential)
        _firebase_messaging = messaging
        _firebase_ready = True
    else:
        logger.warning("Push notifications are disabled; FCM sends are no-ops")
except Exception:
    logger.warning("Firebase credentials are unavailable; FCM sends are no-ops")


def _now_local() -> str:
    return datetime.now(ZoneInfo(settings.timezone)).strftime("%Y-%m-%d %H:%M:%S")


def _send_multicast(message):
    return _firebase_messaging.send_each_for_multicast(message)


def send_to_device(
    device_id: str, title: str, body: str, data: dict[str, str], tag: str | None = None
) -> int:
    """Send through FCM using a new database session; failures are intentionally contained."""
    try:
        if not settings.push_enabled or not _firebase_ready:
            return 0
        notification_type = data.get("type", "test")
        with SessionLocal() as db:
            tokens = db.scalars(
                select(PushTokenModel).join(
                    DeviceSessionModel, PushTokenModel.session_token == DeviceSessionModel.token
                ).where(
                    PushTokenModel.device_id == device_id,
                    DeviceSessionModel.revoked.is_(False),
                )
            ).all()
            if not tokens:
                return 0
            message_data = {key: str(value) for key, value in data.items()}
            message = _firebase_messaging.MulticastMessage(
                notification=_firebase_messaging.Notification(title=title, body=body),
                data=message_data,
                tokens=[token.fcm_token for token in tokens],
                android=_firebase_messaging.AndroidConfig(
                    priority="high",
                    notification=_firebase_messaging.AndroidNotification(
                        channel_id=settings.android_channel_id, tag=tag
                    ),
                ),
            )
            response = _send_multicast(message)
            invalid_codes = {"registration-token-not-registered", "sender-id-mismatch", "invalid-argument"}
            sent = 0
            for token, result in zip(tokens, response.responses):
                if result.success:
                    sent += 1
                elif getattr(result.exception, "code", None) in invalid_codes:
                    db.delete(token)
            db.add(NotificationLogModel(
                device_id=device_id,
                kind=notification_type,
                key=data.get("alert_id", tag or notification_type),
                sent_at=_now_local(),
            ))
            db.commit()
            return sent
    except Exception:
        logger.exception("Push notification failed for device %s", device_id)
        return 0


def submit_notification(*args, **kwargs) -> None:
    _executor.submit(send_to_device, *args, **kwargs)


def notify_alerts(device_id: str, alert_ids: list[int]) -> None:
    try:
        with SessionLocal() as db:
            device = db.get(DeviceModel, device_id)
            alerts = db.scalars(select(AlertModel).where(AlertModel.id.in_(alert_ids))).all()
            if device is None or not alerts:
                return
            cutoff = datetime.now(ZoneInfo(settings.timezone)) - timedelta(
                minutes=settings.alert_notify_cooldown_minutes
            )
            eligible = [
                alert for alert in alerts
                if db.scalar(select(NotificationLogModel.id).where(
                    NotificationLogModel.device_id == device_id,
                    NotificationLogModel.kind == "alert",
                    NotificationLogModel.key == alert.parameter,
                    NotificationLogModel.sent_at >= cutoff.strftime("%Y-%m-%d %H:%M:%S"),
                )) is None
            ]
            if not eligible:
                return
            body = (
                eligible[0].message
                if len(eligible) == 1
                else f"{len(eligible)} new alerts: {', '.join(alert.parameter for alert in eligible)}"
            )
            send_to_device(device_id, device.name, body, {
                "type": "alert",
                "device_id": device_id,
                "alert_id": str(eligible[0].id),
            }, tag="alerts")
            for alert in eligible:
                db.add(NotificationLogModel(
                    device_id=device_id, kind="alert", key=alert.parameter, sent_at=_now_local()
                ))
            db.commit()
    except Exception:
        logger.exception("Alert notification failed for device %s", device_id)
