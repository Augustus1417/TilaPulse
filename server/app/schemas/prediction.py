from pydantic import BaseModel, Field

from app.schemas.sensor_reading import SensorReadingCreate


class PredictionRequest(BaseModel):
    readings: list[SensorReadingCreate] = Field(min_length=1)


class PredictionResponse(BaseModel):
    lstm_probability: float = Field(ge=0, le=1)
    bocpd_probability: float = Field(ge=0, le=1)
    risk_score: float = Field(ge=0, le=1)
    synthetic_model_notice: str