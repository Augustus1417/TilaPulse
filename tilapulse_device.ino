#include <OneWire.h>
#include <DallasTemperature.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiManager.h>   // https://github.com/tzapu/WiFiManager
#include <Preferences.h>
#include <ArduinoJson.h>   // install via Library Manager

// ==========================================
// NETWORK CONFIGURATION
// ==========================================
const char *SETUP_AP_PASSWORD = "";
const char *API_BASE_URL = "https://tilapulse.onrender.com"; // Your locked server link
const char *DEVICE_ID = "TilaPulse_Dev1";
const char *DEVICE_KEY = "tp_dev1_2627";

String READINGS_URL;
String COMMAND_URL;
String SETUP_AP_NAME;

// ==========================================
// PIN CONFIGURATIONS
// ==========================================
#define DO_PIN         35
#define PH_PIN         34
#define ONE_WIRE_BUS   4

// CASING USER INTERFACE PINS
#define CHARGE_SIGNAL_PIN 32  // Wire coming straight from TP4056 + input pad
#define WIFI_RESET_PIN    13  // External Panel Pushbutton (D13)
#define RED_LED_PIN       14  // External Casing Red LED (D14)
#define BLUE_LED_PIN      27  // External Casing Blue LED (D27)

// ==========================================
// CALIBRATION VALUES
// ==========================================
#define VREF 3300.0
#define ADC_RES 4096.0

// Dissolved oxygen (single-point calibration)
float cal1VoltageDO = 1525.0;

// pH calibration (from 3 rounds of buffer measurements).
// Voltage is in millivolts, read with analogReadMilliVolts() at ADC_11db.
// pH = PH_SLOPE * mV + PH_INTERCEPT
const float PH_SLOPE = 0.01886;
const float PH_INTERCEPT = -16.63;
const int PH_SAMPLES = 10;
const int PH_SAMPLE_DELAY_MS = 50;

OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature tempSensor(&oneWire);
WiFiManager wm;

const uint16_t DO_Table[] = {
    14621, 14228, 13829, 13442, 13059, 12698, 12349, 12011, 11687, 11372,
    11071, 10777, 10495, 10221, 9956,  9700,  9453,  9213,  8981,  8757,
    8540,  8331,  8129,  7934,  7746,  7564,  7389,  7219,  7055,  6897,
    6744,  6596,  6453,  6314,  6180,  6050,  5923,  5801,  5567, 5456
};

// FORCE LOCKED ACTIVE TO PREVENT SERVER TIMEOUT BLOCKS
bool readingEnabled = true;

// Command polling is kept frequent on purpose: it keeps the Render server awake
// and lets the device react to server commands quickly.
const unsigned long COMMAND_POLL_INTERVAL_MS = 5000;
unsigned long lastCommandPollMs = 0;

// Sensor readings are posted every 15 minutes
const unsigned long DATA_POST_INTERVAL_MS = 15UL * 60UL * 1000UL; // 900,000 ms
unsigned long lastDataPostMs = 0;
bool firstReadingDone = false; // send one reading right after connecting

// Non-blocking Heartbeat Blink configuration
const unsigned long HEARTBEAT_PERIOD_MS = 5000; // blue LED flashes once every 5 s when working
const unsigned long HEARTBEAT_FLASH_MS  = 200;  // how long each flash stays on
unsigned long lastBlinkMs = 0;
unsigned long blinkIntervalMs = 1000;
bool blueLedState = false;

// ==========================================
// DIRECT CHARGE CAPTURE ENGINE
// ==========================================
void updateCasingInterface() {
    unsigned long currentMs = millis();

    bool isChargerPluggedIn =
        (digitalRead(CHARGE_SIGNAL_PIN) == HIGH);

    // RED LED: Indicates that the charger is plugged in
    if (isChargerPluggedIn) {
        digitalWrite(RED_LED_PIN, HIGH);
    }
    else {
        digitalWrite(RED_LED_PIN, LOW);
    }

    // BLUE LED: Independently indicates Wi-Fi connectivity
    if (WiFi.status() == WL_CONNECTED) {

        // Blink once every 5 seconds
        unsigned long phase = currentMs % HEARTBEAT_PERIOD_MS;

        digitalWrite(
            BLUE_LED_PIN,
            phase < HEARTBEAT_FLASH_MS ? HIGH : LOW
        );

    }
    else {

        // Rapid blinking indicates no Wi-Fi connection
        blinkIntervalMs = 200;

        if (currentMs - lastBlinkMs >= blinkIntervalMs) {
            lastBlinkMs = currentMs;
            blueLedState = !blueLedState;

            digitalWrite(BLUE_LED_PIN, blueLedState);
        }
    }
}

// Runs on its own FreeRTOS task so the LED keeps a steady rhythm even while
// loop() is stuck inside a slow HTTPS request or the sensor sampling.
void casingInterfaceTask(void *parameter) {
    for (;;) {
        updateCasingInterface();
        vTaskDelay(pdMS_TO_TICKS(20));
    }
}

// ==========================================
// WIFI CONFIGURATION ENGINE (NON-BLOCKING)
// ==========================================
void resetWiFiSettingsIfRequested() {
    pinMode(WIFI_RESET_PIN, INPUT_PULLUP);
    delay(100);
    if (digitalRead(WIFI_RESET_PIN) == LOW) {
        Serial.println("[WiFi] Panel button HELD at boot - Erasing saved networks...");
        for (int i = 0; i < 6; i++) {
            digitalWrite(RED_LED_PIN, HIGH); delay(100);
            digitalWrite(RED_LED_PIN, LOW);  delay(100);
        }
        wm.resetSettings();
    }
}

void connectToWiFi() {
    wm.setConfigPortalBlocking(false);
    wm.setConfigPortalTimeout(60);
    wm.autoConnect(SETUP_AP_NAME.c_str());
}

void pollCommand() {
    if (WiFi.status() != WL_CONNECTED) return;
    HTTPClient http;
    http.setTimeout(4000); // don't let a slow poll hold up the loop for long
    http.begin(COMMAND_URL);
    http.addHeader("X-Device-Key", DEVICE_KEY);
    int responseCode = http.GET();
    if (responseCode == 200) {
        String body = http.getString();
        StaticJsonDocument<128> doc;
        DeserializationError err = deserializeJson(doc, body);
        if (!err) {
            // Keep readingEnabled safely true to prevent background freeze cycles
            readingEnabled = true;
        }
    }
    http.end();
}

void postReading(float currentTemperature, float phValue, float doValue) {
    if (WiFi.status() != WL_CONNECTED) return;

    HTTPClient http;
    http.setTimeout(15000); // allow for a slow Render response
    http.begin(READINGS_URL);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-Key", DEVICE_KEY);

    String payload = "{\"device_id\":\"" + String(DEVICE_ID) +
                     "\",\"temperature\":" + String(currentTemperature, 2) +
                     ",\"ph\":" + String(phValue, 2) +
                     ",\"dissolved_oxygen\":" + String(doValue, 2) + "}";

    int responseCode = http.POST(payload);
    Serial.print("[POST] Response code: ");
    Serial.println(responseCode);
    http.end();
}

// ==========================================
// SENSOR READING HELPERS
// ==========================================
float readPHMillivolts() {
    uint32_t totalMillivolts = 0;
    for (int i = 0; i < PH_SAMPLES; i++) {
        totalMillivolts += analogReadMilliVolts(PH_PIN);
        delay(PH_SAMPLE_DELAY_MS);
    }
    return totalMillivolts / (float)PH_SAMPLES;
}

void setup() {
    Serial.begin(115200);
    delay(1000);

    pinMode(RED_LED_PIN, OUTPUT);
    pinMode(BLUE_LED_PIN, OUTPUT);
    pinMode(CHARGE_SIGNAL_PIN, INPUT_PULLDOWN);

    pinMode(DO_PIN, ANALOG);
    pinMode(PH_PIN, ANALOG);
    analogReadResolution(12);
    analogSetPinAttenuation(PH_PIN, ADC_11db); // must match the pH calibration setup
    tempSensor.begin();

    SETUP_AP_NAME = String(DEVICE_ID) + "-Setup";

    resetWiFiSettingsIfRequested();

    WiFi.setTxPower(WIFI_POWER_MINUS_1dBm);

    // Start the independent LED task before connecting so the status LED works throughout
    xTaskCreate(casingInterfaceTask, "CasingLED", 2048, NULL, 1, NULL);

    connectToWiFi();

    READINGS_URL = String(API_BASE_URL) + "/api/readings";
    COMMAND_URL = String(API_BASE_URL) + "/api/devices/" + String(DEVICE_ID) + "/command";
    pollCommand();
}

void loop() {
    wm.process(); // Keep background non-blocking network tasks running

    // LED is handled by casingInterfaceTask(), not here

    if (WiFi.status() != WL_CONNECTED) {
        WiFi.reconnect();
        delay(1000);
        return;
    }

    unsigned long nowMs = millis();

    if (nowMs - lastCommandPollMs >= COMMAND_POLL_INTERVAL_MS) {
        pollCommand();
        lastCommandPollMs = nowMs;
    }

    // This block will safely bypass any corrupted memory locks
    if (!readingEnabled) {
        readingEnabled = true; // Safety kick-back
    }

    // Take a reading right after the first successful connection, then every 15 minutes
    if (!firstReadingDone || (nowMs - lastDataPostMs >= DATA_POST_INTERVAL_MS)) {
        firstReadingDone = true;
        lastDataPostMs = nowMs;

        // Temperature
        tempSensor.requestTemperatures();
        float currentTemperature = tempSensor.getTempCByIndex(0);
        if (currentTemperature == DEVICE_DISCONNECTED_C) currentTemperature = 25.0;

        // Dissolved oxygen
        uint32_t rawDO = analogRead(DO_PIN);
        float voltageDO = (float)rawDO * VREF / ADC_RES;
        int tempIndex = (int)currentTemperature;
        if (tempIndex < 0) tempIndex = 0;
        if (tempIndex > 39) tempIndex = 39; // DO_Table has 40 entries (0-39 C)
        float maxSaturationDO = (float)DO_Table[tempIndex] / 1000.0;
        float doValue = voltageDO * maxSaturationDO / cal1VoltageDO;

        // pH (calibrated linear fit, averaged millivolt reading)
        float voltagePH = readPHMillivolts();
        float phValue = PH_SLOPE * voltagePH + PH_INTERCEPT;

        // Terminal printout
        Serial.print(" [MONITOR] ");
        Serial.print("Temp: "); Serial.print(currentTemperature, 1); Serial.print(" C | ");
        Serial.print("DO: "); Serial.print(doValue, 2); Serial.print(" mg/L | ");
        Serial.print("pH voltage: "); Serial.print(voltagePH, 1); Serial.print(" mV -> ");
        Serial.print("pH Value: "); Serial.println(phValue, 2);

        postReading(currentTemperature, phValue, doValue);
    }
}
