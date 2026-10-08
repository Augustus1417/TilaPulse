"""Central assumptions for the synthetic AI pipeline.

Every value in this module is a development assumption, replace with real
farm/BFAR data before treating model results as operational evidence.
"""

from dataclasses import dataclass


FEATURE_NAMES = ("temperature", "ph", "dissolved_oxygen")
SYNTHETIC_MODEL_NOTICE = (
    "This model was trained and evaluated on synthetic data only; results "
    "validate the pipeline and are not evidence of real disease prediction."
)


@dataclass(frozen=True)
class AIConfig:
    # assumption, replace with real farm/BFAR data
    sample_interval_minutes: int = 15
    # assumption, replace with real farm/BFAR data
    window_size: int = 20
    # assumption, replace with real farm/BFAR data
    horizon: int = 5
    # assumption, replace with real farm/BFAR data
    simulator_length: int = 60
    # assumption, replace with real farm/BFAR data
    dropout_probability: float = 0.04
    # assumption, replace with real farm/BFAR data
    label_noise: float = 0.08
    # assumption, replace with real farm/BFAR data
    bocpd_hazard: float = 1.0 / 30.0
    # assumption, replace with real farm/BFAR data
    bocpd_max_run_length: int = 80
    # assumption, replace with real farm/BFAR data
    bocpd_short_run_length: int = 3
    # assumption, replace with real farm/BFAR data
    bocpd_warmup: int = 10
    # assumption, replace with real farm/BFAR data
    temperature_baseline: float = 27.0
    # assumption, replace with real farm/BFAR data
    ph_baseline: float = 7.2
    # assumption, replace with real farm/BFAR data
    dissolved_oxygen_baseline: float = 5.5
    # assumption, replace with real farm/BFAR data
    temperature_noise: float = 0.22
    # assumption, replace with real farm/BFAR data
    ph_noise: float = 0.035
    # assumption, replace with real farm/BFAR data
    dissolved_oxygen_noise: float = 0.18
    # assumption, replace with real farm/BFAR data
    risk_low_threshold: float = 0.30
    # assumption, replace with real farm/BFAR data
    risk_high_threshold: float = 0.60
    # assumption, replace with real farm/BFAR data
    fusion_alpha: float = 0.7
    # assumption, replace with real farm/BFAR data
    fusion_beta: float = 0.3


AI_CONFIG = AIConfig()
