from collections.abc import Callable
from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import DO_MIN_MGL, PH_MAX, PH_MIN, TEMP_MAX_C, TEMP_MIN_C, settings
from app.models import AlertModel, ReadingModel


def _now_local() -> str:
    return datetime.now(ZoneInfo(settings.timezone)).strftime("%Y-%m-%d %H:%M:%S")


def evaluate_reading_alerts(reading: ReadingModel, db: Session) -> None:
    checks: tuple[tuple[str, float, Callable[[float], bool], str, str], ...] = (
        (
            "temperature",
            reading.temperature,
            lambda value: value < TEMP_MIN_C,
            "below_min",
            f"Temperature is critically low ({reading.temperature:.1f} C)",
        ),
        (
            "temperature",
            reading.temperature,
            lambda value: value > TEMP_MAX_C,
            "above_max",
            f"Temperature is critically high ({reading.temperature:.1f} C)",
        ),
        (
            "ph",
            reading.ph,
            lambda value: value < PH_MIN,
            "below_min",
            f"pH is critically low ({reading.ph:.2f})",
        ),
        (
            "ph",
            reading.ph,
            lambda value: value > PH_MAX,
            "above_max",
            f"pH is critically high ({reading.ph:.2f})",
        ),
        (
            "dissolved_oxygen",
            reading.dissolved_oxygen,
            lambda value: value < DO_MIN_MGL,
            "below_min",
            f"Dissolved oxygen is critically low ({reading.dissolved_oxygen:.1f} mg/L)",
        ),
    )

    for parameter, value, is_breached, threshold_breached, message in checks:
        if not is_breached(value):
            continue
        existing = db.scalar(
            select(AlertModel).where(
                AlertModel.device_id == reading.device_id,
                AlertModel.parameter == parameter,
            )
        )
        if existing is None:
            db.add(
                AlertModel(
                    device_id=reading.device_id,
                    parameter=parameter,
                    value=value,
                    threshold_breached=threshold_breached,
                    message=message,
                    created_at=_now_local(),
                )
            )