import secrets

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db import get_db
from app.models import DeviceModel, DeviceSessionModel


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer_scheme = HTTPBearer(auto_error=False)


def hash_device_key(device_key: str) -> str:
    return pwd_context.hash(device_key)


def verify_device_key(device_key: str, device_key_hash: str | None) -> None:
    try:
        valid = bool(device_key_hash and pwd_context.verify(device_key, device_key_hash))
    except ValueError:
        # bcrypt only accepts passwords up to 72 bytes.
        valid = False
    if not valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing device key",
        )


def verify_admin_key(x_admin_key: str | None = Header(default=None)) -> None:
    if not settings.admin_api_key or not x_admin_key or not secrets.compare_digest(
        x_admin_key, settings.admin_api_key
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing admin key",
        )


def verify_ingestion_device_key(device_key_hash: str, x_device_key: str | None) -> None:
    if not x_device_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing device key",
        )
    verify_device_key(x_device_key, device_key_hash)


def verify_device_session(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> str:
    token = credentials.credentials if credentials and credentials.scheme.lower() == "bearer" else None
    session = db.scalar(
        select(DeviceSessionModel).where(
            DeviceSessionModel.token == token,
            DeviceSessionModel.revoked.is_(False),
        )
    ) if token else None
    if session is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or revoked session")
    request.state.device_session_token = session.token
    return session.device_id