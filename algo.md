# TilaPulse algorithm overview

TilaPulse is a water-quality monitoring system for tilapia ponds. It does two related things:

1. **Immediate rule-based safety alerts** for abnormal temperature, pH, or dissolved oxygen.
2. **A broader risk assessment** intended to estimate whether recent sensor patterns resemble an upcoming stressful event.

The algorithm runs primarily in the Python backend under `server/app/`.

> Important limitation: the included LSTM was trained only on synthetic data. The code explicitly says its results are not evidence of real disease prediction. See `ai_config.py`.

---

## 1. Purpose and users of the output

### Immediate water-quality alerts

Every submitted reading is checked against fixed healthy ranges in `alerts.py`:

| Measurement | Alert condition |
|---|---|
| Temperature | Below `24.0 C` or above `32.0 C` |
| pH | Below `6.5` or above `8.5` |
| Dissolved oxygen | Below `5.0 mg/L` |

These alerts are:

- Stored in the database.
- Shown through the API and Flutter app.
- Optionally sent as Android push notifications through Firebase Cloud Messaging.

The alert system detects current threshold breaches. It is not the machine-learning prediction.

### Risk prediction

The prediction system combines:

- An LSTM neural network probability.
- A Bayesian Online Change Point Detection probability, called BOCPD.

The result is stored as a risk assessment and displayed by the Flutter app. See:

- `prediction.py`
- `prediction_runner.py`
- `predict.py`
- `risk_prediction.dart`

The output is intended to help a pond operator decide whether to investigate the pond.

---

# 2. Inputs

## Sensor fields

Each reading contains exactly these fields:

```json
{
  "device_id": "TilaPulse_Dev1",
  "temperature": 27.4,
  "ph": 7.2,
  "dissolved_oxygen": 5.8
}
```

The API schema is defined in `schemas.py`:

- `device_id`: required string, 1–120 characters.
- `temperature`: number from `-10` to `60`.
- `ph`: number from `0` to `14`.
- `dissolved_oxygen`: number from `0` to `20`.

Extra fields are rejected.

## Physical sensor source

The ESP32 firmware in `tilapulse_device.ino` produces the values:

- **Temperature:** Dallas temperature sensor.
- **Dissolved oxygen:** analog voltage converted using a temperature-indexed saturation table.
- **pH:** ten analog voltage samples averaged, then converted with:

```text
pH = 0.01886 × voltage_mV − 16.63
```

The firmware posts one reading immediately after connection and then approximately every **15 minutes**.

It sends readings to:

```text
POST /api/readings
```

The backend stores them as `ReadingModel` rows in `models.py`.

## Historical data used by prediction

When prediction runs, `prediction_runner.py` loads all stored readings for the selected device, ordered oldest to newest.

It does not mix readings from different devices.

The configured model window is **20 readings**, defined in `ai_config.py`.

At the firmware’s normal 15-minute interval, 20 readings represent approximately **5 hours**.

---

# 3. Processing steps

## Step 1: Receive and validate a reading

`create_reading` does the following:

1. Looks up the device.
2. Verifies the device key.
3. Saves the three sensor values.
4. Updates `last_seen`.
5. Evaluates threshold alerts.
6. Queues push notification work if a new alert was created.

The reading is rejected if the device is unknown, authentication fails, or the values violate the Pydantic ranges.

---

## Step 2: Check fixed safety thresholds

`evaluate_reading_alerts` checks each field.

For example:

```text
temperature = 20.0
```

creates a temperature alert because:

```text
20.0 < 24.0
```

The system stores at most one active alert per device and parameter. Repeated low-temperature readings do not create duplicate temperature alerts until the existing alert is deleted.

---

## Step 3: Start a prediction

A prediction can be started in two ways:

### Manual prediction

The authenticated app calls:

```text
POST /api/devices/{device_id}/predict
```

Implemented in `predict.py`.

### Scheduled prediction

The scheduler in `scheduler.py` normally checks devices every **60 minutes**.

A scheduled prediction is skipped when:

- The device has reading disabled.
- The device is offline.
- There are fewer than **20 readings**.
- There is no new reading since the previous prediction.
- The previous prediction is still considered recent.

The schedule and minimum reading count can be changed through configuration.

---

## Step 4: Clean and fill missing sensor values

The prediction pipeline begins in `SensorPreprocessor`.

The fields are always processed in this order:

```text
temperature, ph, dissolved_oxygen
```

For each value:

- Numeric values are converted to `float`.
- Missing values, non-numeric values, `NaN`, and infinity are replaced with the previous value for that sensor.
- Initially, the previous value is `0.0`.

For example:

```text
[
  {temperature: 27, ph: 7.2, dissolved_oxygen: 5.5},
  {temperature: null, ph: 7.3, dissolved_oxygen: 5.4}
]
```

becomes effectively:

```text
[
  [27.0, 7.2, 5.5],
  [27.0, 7.3, 5.4]
]
```

This behavior is in `SensorPreprocessor._raw`.

---

## Step 5: Normalize the values

The model does not use raw values directly. It applies training-time z-score normalization:

```text
normalized value = (value − mean) / scale
```

The checked-in model metadata in `lstm_model.json` contains:

| Feature | Mean | Scale |
|---|---:|---:|
| Temperature | `27.2291344138` | `0.8377895364` |
| pH | `7.2127232928` | `0.1800583370` |
| Dissolved oxygen | `5.2910387660` | `0.4600577445` |

The model refuses a checkpoint if the feature order does not match the API.

---

## Step 6: Construct a 20-reading window

`SensorPreprocessor.window` keeps the latest 20 normalized readings.

- If there are more than 20 readings, only the newest 20 are used.
- If there are fewer than 20, the first available transformed reading is repeated at the beginning.
- If there are no records, it creates an all-zero window.

In normal operation, the API requires stored readings before prediction, so the empty case is unlikely through the public endpoint.

---

## Step 7: Calculate the LSTM probability

The LSTM is defined in `lstm.py`.

Its structure is:

1. Three input features per time step.
2. A one-directional LSTM with hidden size **32**.
3. A linear layer.
4. A sigmoid output between `0` and `1`.

The model reads the 20-reading sequence and uses the final time step to produce:

```text
lstm_probability
```

A value closer to `1` means the model considers the pattern more similar to its positive training examples.

The model was trained by `train_lstm.py` on:

- 300 synthetic sequences.
- 210 training sequences.
- 45 validation sequences.
- 45 test sequences.
- Random seed `42`.
- Adam learning rate `0.003`.
- Up to 60 epochs.
- Early stopping after 8 validation rounds without improvement.

The synthetic scenarios include:

- Normal.
- Gradual degradation.
- Abrupt event.
- Stress and recovery.
- Noisy normal.

The training label represents whether an event onset occurs in the final **5-step horizon**, but the deployed prediction itself is only a probability; it does not return a specific cause or forecast time.

---

## Step 8: Calculate the BOCPD change-point probability

The second detector is `BOCPD`.

In plain language, it asks:

> “Do the latest measurements look like the pond has shifted from its previous pattern?”

It maintains possible run lengths: how many observations have occurred since the last likely change.

For every observation, it:

1. Calculates how probable the new values are under each existing pattern.
2. Either:
   - Extends the existing pattern, or
   - Starts a new pattern.
3. Normalizes the probabilities.
4. Reports the probability mass for short run lengths.

Important defaults:

- Hazard probability: `1/30`, approximately `0.0333`.
- Maximum run length: `80`.
- “Short” run length: `3`.
- Warm-up period: `10` observations.
- Three sensors are treated as conditionally independent.
- Their log predictive probabilities are added together.

Before 10 observations, the reported BOCPD score is `0.0`.

The result is:

```text
bocpd_probability
```

It is constrained to the range `0.0` to `1.0`.

---

## Step 9: Combine the two probabilities

The combination happens in `PredictionService.predict`:

```text
risk_score =
    alpha × lstm_probability
  + beta  × bocpd_probability
```

The default application configuration in `ai_config.py` is:

```text
alpha = 0.7
beta  = 0.3
```

Therefore, by default:

```text
risk_score = 0.7 × LSTM + 0.3 × BOCPD
```

However, `prediction_alpha` and `prediction_beta` can be overridden through environment settings.

### Configuration inconsistency

The repository also contains `fusion_config.json`, which says:

```json
{
  "alpha": 1.0,
  "beta": 0.0
}
```

But I found no code that loads this JSON file. The running service uses `settings.prediction_alpha`, whose default comes from `AI_CONFIG` and is therefore `0.7 / 0.3`.

So the artifact currently appears to be documentation or an old evaluation output, not the live fusion configuration.

---

## Step 10: Assign a risk label

`_risk_label` uses these default thresholds:

```text
risk_score < 0.30       => low
0.30 <= score < 0.60    => moderate
risk_score >= 0.60      => high
```

The values can be overridden through:

```text
PREDICTION_RISK_LOW_THRESHOLD
PREDICTION_RISK_HIGH_THRESHOLD
```

A stored prediction contains:

- `risk_score`
- `lstm_probability`
- `bocpd_change_point_probability`
- `risk_label`
- Timestamp
- Whether it was `manual` or `scheduled`

---

## Step 11: Notify on a newly high prediction

If a prediction becomes `high`, and the previous prediction was not already `high`, `run_prediction` submits a notification such as:

```text
Disease risk is now high (72%)
```

Push delivery is handled by `notifications.py`.

---

# 4. Decisions, thresholds, weights, and formulas

## Threshold alerts

Defined in `config.py`:

```text
Temperature minimum: 24.0 C
Temperature maximum: 32.0 C
pH minimum:          6.5
pH maximum:          8.5
Dissolved oxygen:    5.0 mg/L minimum
```

The comparisons are strict:

- `temperature < 24.0` alerts.
- `temperature == 24.0` does not.
- `temperature > 32.0` alerts.
- `temperature == 32.0` does not.

## Risk labels

```text
low:      score < 0.30
moderate: 0.30 <= score < 0.60
high:     score >= 0.60
```

## Fusion

Default:

```text
70% LSTM
30% BOCPD
```

## BOCPD

```text
hazard = 1 / 30
maximum run length = 80
short run length = 3
warm-up = 10 readings
```

## Client-side BOCPD display threshold

The Flutter client defines `bocpdAlertThreshold = 0.5` in `constants.dart`.

That appears to control presentation of a change-point warning in the app. It does **not** change the backend risk score or backend risk label.

---

# 5. Outputs and examples

## Example A: fixed threshold alert

Input:

```json
{
  "device_id": "pond-a",
  "temperature": 20.0,
  "ph": 7.2,
  "dissolved_oxygen": 6.0
}
```

Result:

- Reading is accepted because all values satisfy the API’s broad validation ranges.
- A temperature alert is created because `20.0 < 24.0`.
- No pH or dissolved-oxygen alert is created.

The alert contains values like:

```json
{
  "device_id": "pond-a",
  "parameter": "temperature",
  "value": 20.0,
  "threshold_breached": "below_min",
  "message": "Temperature is critically low (20.0 C)"
}
```

The alert ID and timestamp are generated by the database/server.

## Example B: risk-label calculation

Suppose the two model components return:

```text
lstm_probability = 0.20
bocpd_probability = 0.10
```

Using the default weights:

```text
risk_score = (0.7 × 0.20) + (0.3 × 0.10)
           = 0.14 + 0.03
           = 0.17
```

Since `0.17 < 0.30`, the stored result is:

```json
{
  "risk_score": 0.17,
  "lstm_probability": 0.2,
  "bocpd_change_point_probability": 0.1,
  "risk_label": "low"
}
```

This exact style of test value is used in `test_predict.py`.

This is a calculation example, not a claim that those are the real outputs for a particular pond. The actual LSTM output depends on the loaded checkpoint and the preceding readings.

---

# 6. Edge cases

## Missing or invalid sensor values

At the API boundary:

- Missing required fields are rejected.
- Extra fields are rejected.
- Values outside the declared numeric ranges are rejected.

Inside the prediction preprocessor:

- `None`, non-numeric values, `NaN`, and infinity are replaced with the previous value for that feature.
- If there is no previous value, the fallback is `0.0`.

The firmware has its own fallback:

- If the temperature sensor reports `DEVICE_DISCONNECTED_C`, it substitutes `25.0 C`.

## Too few readings

Manual prediction can run with stored readings even if fewer than 20 exist. The preprocessor pads the front of the sequence.

Scheduled prediction requires at least 20 readings by default.

## No readings

`run_prediction` raises:

```text
ValueError("No readings found for device")
```

The API returns HTTP `404`.

## Missing model or invalid model

If the checkpoint is unavailable or cannot be loaded:

- Startup leaves the prediction service without a model.
- A prediction request returns HTTP `503`.
- The error says the trained LSTM model is missing or unavailable.

The checkpoint must contain validated metadata, including:

- Correct feature order.
- Synthetic-data marker.
- Window size.
- Hidden size.
- Scaler statistics.

## BOCPD unusual values

BOCPD ignores non-finite individual values when calculating predictive likelihoods and keeps the previous state for that feature.

It returns `0.0` during warm-up and keeps its output between `0.0` and `1.0`.

## Duplicate alerts

Only one active alert is kept for each device and parameter. A repeated breach does not create duplicates. Deleting the alert allows a later breach to create a new one.

## Device isolation

Predictions and readings are scoped by `device_id`. The tests specifically verify that one device’s prediction cannot use another device’s readings.

---

# 7. External services, models, and configuration

## External/runtime dependencies

The backend depends on:

- FastAPI and Uvicorn.
- SQLAlchemy.
- PyTorch.
- APScheduler.
- Pydantic.
- Firebase Admin SDK for push notifications.
- SQLite locally or PostgreSQL in production.

Dependencies are listed in `requirements.txt`.

## Model checkpoint

The deployed model is:

```text
server/models/lstm_model.pt
```

Its metadata is also exposed in:

```text
server/models/lstm_model.json
```

The model is synthetic-data-only and has a recorded validation PR-AUC of approximately `0.606`.

That metric does not establish real-world disease-prediction accuracy.

## Database

Readings, alerts, and predictions are stored in the configured database. The database setting is normally `DATABASE_URL`, with `DB_CONNECTION_STRING` supported as a compatibility alias.

## Scheduler configuration

Relevant settings include:

```text
PREDICTION_INTERVAL_MINUTES = 60
PREDICTION_MIN_READINGS = 20
SCHEDULER_ENABLED = true
```

## Notifications

Firebase push notifications require credentials through either:

- `FIREBASE_CREDENTIALS_JSON`, or
- `GOOGLE_APPLICATION_CREDENTIALS`.

If credentials are unavailable, notification sends become no-ops with a warning; the API and prediction storage continue to function.

---

## Bottom line for a non-technical explanation

You can describe TilaPulse this way:

> “The device periodically measures temperature, pH, and oxygen in the pond. TilaPulse first checks whether any measurement is outside a safe range and immediately records an alert. Separately, it looks at the recent sequence of measurements—normally the last 20 readings—and uses one learned model plus one change-detection method to estimate whether the pattern looks risky. Those two scores are combined into a number from 0 to 1, then classified as low, moderate, or high. The current model is a development prototype trained on simulated data, so its risk score should be treated as an experimental warning signal, not a confirmed disease diagnosis.”