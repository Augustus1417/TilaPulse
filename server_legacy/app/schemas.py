from pydantic import BaseModel, ConfigDict, Field


class SensorReadingCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_id: str = Field(min_length=1)
    temperature: float = Field(ge=-10, le=60)
    ph: float = Field(ge=0, le=14)
    dissolved_oxygen: float = Field(ge=0, le=20)


class SensorReading(SensorReadingCreate):
    timestamp: str


class PredictionRequest(BaseModel):
    device_id: str = Field(min_length=1)


class PredictionResponse(BaseModel):
    lstm_probability: float
    bocpd_probability: float
    risk_score: float
    synthetic_model_notice: str