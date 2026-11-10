# TilaPulse pH Sensor Calibration

## 1. Calibration Values

The pH sensor uses a linear calibration equation derived from three rounds of buffer-solution measurements.

The code defines two calibration constants:

```cpp
const float PH_SLOPE = 0.01886;
const float PH_INTERCEPT = -16.63;
```

These values are used in the following equation:

\[
\boxed{pH=(0.01886\times V)-16.63}
\]

Where:
- **V:** Measured sensor voltage in millivolts (mV).
- **0.01886:** Calibration slope.
- **-16.63:** Calibration intercept.

The slope and intercept establish the mathematical relationship between the sensor's voltage output and the corresponding pH value.

## 2. Voltage Sampling

Before applying the calibration equation, the ESP32 collects ten voltage readings from the pH sensor.

```cpp
const int PH_SAMPLES = 10;
const int PH_SAMPLE_DELAY_MS = 50;
```

The readings are averaged to reduce measurement fluctuations.

The averaging formula is:

\[
V_{avg}=\frac{V_1+V_2+\cdots+V_{10}}{10}
\]

The resulting average voltage is used as the input for the calibration equation.

## 3. Applying the Calibration Equation

The code performs the conversion using:

```cpp
float voltagePH = readPHMillivolts();
float phValue = PH_SLOPE * voltagePH + PH_INTERCEPT;
```

For example, assuming the average voltage is 1501 mV:

\[
pH=(0.01886\times1501)-16.63
\]

\[
pH=28.30886-16.63
\]

\[
\boxed{pH=11.68}
\]

The resulting value is the calculated pH measurement, which is subsequently transmitted to the TilaPulse server.

## 4. Origin of the Calibration Values

The slope and intercept were obtained through linear regression using known pH buffer values and their corresponding measured voltages.

The general linear equation is:

\[
y=mx+b
\]

For the pH sensor:

\[
pH=mV+b
\]

The regression produced:

- Slope (\(m\)): 0.01886
- Intercept (\(b\)): -16.63

These values are stored in the firmware and reused during subsequent measurements. The device does not need to repeat the buffer-solution calibration every time it measures water.

## 5. Summary

The pH sensor produces an electrical voltage rather than directly measuring pH. The ESP32 collects ten voltage samples, calculates their average, and applies the previously established linear calibration equation to convert the measured voltage into a pH value.

**In essence, the calibration equation allows the device to translate electrical voltage measurements into meaningful pH readings.**