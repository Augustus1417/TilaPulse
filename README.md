# TilaPulse

TilaPulse is a prototype tilapia pond monitoring system designed to help track water quality conditions in near real time. One ESP32 device sends temperature, pH, and dissolved oxygen readings to a FastAPI backend, and a Flutter app presents the latest data in a simple dashboard.

## What the project does

- Collects water quality readings from an ESP32 sensor device
- Validates and timestamps incoming measurements in the backend
- Stores recent readings in memory for quick access
- Displays the most recent values in the Flutter interface
- Provides an experimental prediction pipeline that estimates risk using sensor trends over time

## System overview

```text
ESP32 sensor device
  -> sends readings to the backend
  -> FastAPI validates and stores the data
  -> Flutter app reads the latest sensor values
  -> optional ML risk analysis runs on recent readings
```

## Project status

This is a prototype. It focuses on proof-of-concept monitoring and analysis rather than a production farm-management system.

For backend implementation details, see [MANUAL.md](MANUAL.md).
