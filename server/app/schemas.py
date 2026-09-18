from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_serializer


class SensorReadingCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    temperature: float = Field(ge=-10, le=60)
    ph: float = Field(ge=0, le=14)
    dissolved_oxygen: float = Field(ge=0, le=20)


class SensorReading(SensorReadingCreate):
    timestamp: datetime

    @field_serializer("timestamp")
    def serialize_timestamp(self, timestamp: datetime) -> str:
        return timestamp.strftime("%Y-%m-%d %H:%M:%S")


class PredictionRequest(BaseModel):
    readings: list[SensorReadingCreate] = Field(min_length=1)


class PredictionResponse(BaseModel):
    lstm_probability: float
    bocpd_probability: float
    risk_score: float
    synthetic_model_notice: str