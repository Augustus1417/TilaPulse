import secrets

from fastapi import Header, HTTPException, status

from app.core.config import settings


def verify_admin_key(x_admin_key: str | None = Header(default=None)) -> None:
    if not settings.admin_api_key or not x_admin_key or not secrets.compare_digest(
        x_admin_key, settings.admin_api_key
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing admin key",
        )


def verify_device_key(expected_key: str, x_device_key: str | None) -> None:
    if not x_device_key or not secrets.compare_digest(x_device_key, expected_key):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing device key",
        )