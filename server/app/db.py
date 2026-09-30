from collections.abc import Generator

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings


engine_options: dict[str, object] = {"pool_pre_ping": True}
if settings.database_url.startswith("sqlite"):
    engine_options["connect_args"] = {"check_same_thread": False}

engine = create_engine(settings.database_url, **engine_options)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def migrate_auth_schema() -> None:
    inspector = inspect(engine)
    if not inspector.has_table("devices"):
        return

    columns = {column["name"] for column in inspector.get_columns("devices")}
    if "device_key" not in columns:
        return

    # Hash legacy plaintext keys before removing the old column.
    from app.core.security import hash_device_key

    with engine.begin() as connection:
        if "device_key_hash" not in columns:
            connection.execute(text("ALTER TABLE devices ADD COLUMN device_key_hash VARCHAR(200)"))
        legacy_devices = connection.execute(
            text("SELECT device_id, device_key FROM devices WHERE device_key_hash IS NULL")
        ).mappings()
        for device in legacy_devices:
            connection.execute(
                text("UPDATE devices SET device_key_hash = :device_key_hash WHERE device_id = :device_id"),
                {
                    "device_id": device["device_id"],
                    "device_key_hash": hash_device_key(device["device_key"]),
                },
            )
        connection.execute(text("ALTER TABLE devices DROP COLUMN device_key"))