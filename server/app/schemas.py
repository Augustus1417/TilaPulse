from pydantic import BaseModel, ConfigDict, Field


class ReadingIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_id: str = Field(min_length=1, max_length=120)
    temperature: float = Field(ge=-10, le=60)
    ph: float = Field(ge=0, le=14)
    dissolved_oxygen: float = Field(ge=0, le=20)


class ReadingOut(ReadingIn):
    timestamp: str


class DeviceRegisterIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_id: str = Field(min_length=1, max_length=120)
    name: str = Field(min_length=1, max_length=200)
    device_key: str | None = Field(default=None, min_length=8, max_length=200)


class DeviceOut(BaseModel):
    device_id: str
    name: str
    created_at: str
    last_seen: str | None
    reading_enabled: bool
    online: bool


class DeviceAdminOut(DeviceOut):
    pass


class DeviceRegistrationOut(DeviceOut):
    device_key: str
    warning: str = "This key is shown once and is non-retrievable afterward."


class DeviceConnectIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_id: str = Field(min_length=1, max_length=120)
    device_key: str = Field(min_length=1, max_length=200)


class DeviceConnectOut(BaseModel):
    token: str


class ReadingStateUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    enabled: bool


class PredictionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_id: str = Field(min_length=1, max_length=120)
    readings: list[ReadingIn] | None = None


class PredictionResponse(BaseModel):
    device_id: str
    lstm_probability: float
    bocpd_probability: float
    risk_score: float
    synthetic_model_notice: str