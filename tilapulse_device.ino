#include <OneWire.h>
#include <DallasTemperature.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiManager.h>   // https://github.com/tzapu/WiFiManager - install via Library Manager
#include <Preferences.h>
#include <ArduinoJson.h>   // install via Library Manager - used to parse the command response

// ==========================================
// 🌐 NETWORK CONFIGURATION
// ==========================================
// SETUP_AP_NAME is no longer a fixed string - it's built from DEVICE_ID below
// (in setup()) so each physical unit shows its own distinct setup AP, e.g.
// "TilaPulse_Dev1-Setup", instead of every device showing the same name.
const char *SETUP_AP_PASSWORD = "";

const char *API_BASE_URL = "https://tilapulse.onrender.com";
const char *DEVICE_ID = "TilaPulse_Dev1";
const char *DEVICE_KEY = "tp_dev1_2627";

// Derived endpoint URLs and AP name (built once in setup())
String READINGS_URL;
String COMMAND_URL;
String SETUP_AP_NAME;

// ==========================================
// 📌 PIN CONFIGURATIONS
// ==========================================
#define DO_PIN    35
#define PH_PIN    34
#define ONE_WIRE_BUS 4
#define WIFI_RESET_PIN 0

// ==========================================
// 🛠️ CALIBRATION VALUES
// ==========================================
#define VREF 3300.0
#define ADC_RES 4096.0

float cal1VoltageDO = 1525.0;
float phNeutralVoltage = 1500.0;
float phAcidVoltage    = 2032.0;

OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature tempSensor(&oneWire);
WiFiManager wm;

const uint16_t DO_Table[] = {
    14621, 14228, 13829, 13442, 13059, 12698, 12349, 12011, 11687, 11372,
    11071, 10777, 10495, 10221, 9956,  9700,  9453,  9213,  8981,  8757,
    8540,  8331,  8129,  7934,  7746,  7564,  7389,  7219,  7055,  6897,
    6744,  6596,  6453,  6314,  6180,  6050,  5923,  5801,  5682,  5567, 5456
};

// ==========================================
// ▶️⏸️ REMOTE START/STOP STATE
// ==========================================
// Desired state as last reported by the server. Starts true so a brand-new
// device reads by default until someone explicitly pauses it from the app.
bool readingEnabled = true;

// How often to check in with the server for the current command/heartbeat,
// independent of the sensor sample rate - this keeps last_seen (and so the
// app's "online" indicator) fresh even while paused.
const unsigned long COMMAND_POLL_INTERVAL_MS = 5000; // every 5 seconds
unsigned long lastCommandPollMs = 0;

// ==========================================
// 📶 WIFI PROVISIONING
// ==========================================
void resetWiFiSettingsIfRequested() {
    pinMode(WIFI_RESET_PIN, INPUT_PULLUP);
    delay(50);
    if (digitalRead(WIFI_RESET_PIN) == LOW) {
        Serial.println("[WiFi] Reset pin held LOW at boot - erasing saved WiFi credentials.");
        wm.resetSettings();
    }
}

void connectToWiFi() {
    wm.setAPCallback([](WiFiManager *manager) {
        Serial.println("==================================================");
        Serial.print("[WiFi] No saved network found. Setup AP started: ");
        Serial.println(SETUP_AP_NAME);
        Serial.println("[WiFi] Connect a phone to that WiFi network to configure it.");
        Serial.println("==================================================");
    });

    wm.setConfigPortalTimeout(180);

    bool connected;
    if (strlen(SETUP_AP_PASSWORD) > 0) {
        connected = wm.autoConnect(SETUP_AP_NAME.c_str(), SETUP_AP_PASSWORD);
    } else {
        connected = wm.autoConnect(SETUP_AP_NAME.c_str());
    }

    if (connected) {
        Serial.print("[WiFi] Connected. ESP32 IP: ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println("[WiFi] Setup portal timed out with no connection. Restarting to retry...");
        delay(1000);
        ESP.restart();
    }
}

// ==========================================
// ▶️⏸️ COMMAND / HEARTBEAT CHECK-IN
// ==========================================
// Polls GET /api/devices/{device_id}/command. This call alone updates the
// device's last_seen on the server (it's the heartbeat), regardless of
// whether reading is currently enabled - so "online" status reflects real
// connectivity, separate from whether sampling is paused.
void pollCommand() {
    if (WiFi.status() != WL_CONNECTED) return;

    HTTPClient http;
    http.begin(COMMAND_URL);
    http.addHeader("X-Device-Key", DEVICE_KEY);

    int responseCode = http.GET();
    if (responseCode == 200) {
        String body = http.getString();
        StaticJsonDocument<128> doc;
        DeserializationError err = deserializeJson(doc, body);
        if (!err) {
            bool newState = doc["reading_enabled"] | true; // default true on parse gap
            if (newState != readingEnabled) {
                Serial.print("[Command] reading_enabled changed to: ");
                Serial.println(newState ? "true (resuming)" : "false (pausing)");
            }
            readingEnabled = newState;
        } else {
            Serial.println("[Command] Failed to parse response, keeping last known state.");
        }
    } else if (responseCode > 0) {
        Serial.print("[Command] Unexpected response code: ");
        Serial.println(responseCode);
    } else {
        Serial.print("[Command] Request failed: ");
        Serial.println(http.errorToString(responseCode));
    }
    http.end();
}

void postReading(float currentTemperature, float phValue, float doValue) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[WARN] Reading not sent: Wi-Fi is disconnected.");
        return;
    }

    HTTPClient http;
    http.begin(READINGS_URL);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-Key", DEVICE_KEY);

    String payload = "{\"device_id\":\"" + String(DEVICE_ID) +
                     "\",\"temperature\":" + String(currentTemperature, 2) +
                     ",\"ph\":" + String(phValue, 2) +
                     ",\"dissolved_oxygen\":" + String(doValue, 2) + "}";

    int responseCode = http.POST(payload);
    if (responseCode > 0) {
        Serial.print("API response: ");
        Serial.print(responseCode);
        Serial.print(" ");
        Serial.println(http.getString());
    } else {
        Serial.print("[ERROR] API request failed: ");
        Serial.println(http.errorToString(responseCode));
    }
    http.end();
}

void setup() {
    Serial.begin(115200);
    delay(1000);

    pinMode(DO_PIN, ANALOG);
    pinMode(PH_PIN, ANALOG);
    analogReadResolution(12);

    tempSensor.begin();

    // Build the setup AP name from DEVICE_ID, e.g. "TilaPulse_Dev1-Setup",
    // so each physical unit is distinguishable during WiFi provisioning.
    SETUP_AP_NAME = String(DEVICE_ID) + "-Setup";

    resetWiFiSettingsIfRequested();
    connectToWiFi();

    READINGS_URL = String(API_BASE_URL) + "/api/readings";
    COMMAND_URL = String(API_BASE_URL) + "/api/devices/" + String(DEVICE_ID) + "/command";

    Serial.println("--- All 3 Sensors Initialized (DS18B20 Active) ---");

    // Check in once immediately at boot so the device shows online right away
    // and picks up the current desired state before the first sample loop.
    pollCommand();
}

void loop() {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[WiFi] Connection lost, attempting to reconnect...");
        WiFi.reconnect();
        delay(2000);
        return; // skip this cycle, try again next loop
    }

    // Check in with the server on its own interval, independent of the
    // sensor sampling below - this is what keeps "online" accurate even
    // while paused.
    unsigned long nowMs = millis();
    if (nowMs - lastCommandPollMs >= COMMAND_POLL_INTERVAL_MS) {
        pollCommand();
        lastCommandPollMs = nowMs;
    }

    if (!readingEnabled) {
        Serial.println("[Paused] reading_enabled is false - skipping sensor read/post.");
        delay(1000);
        return;
    }

    // ----------------------------------------------------
    // 1. READ DIGITAL TEMPERATURE SENSOR (DS18B20)
    // ----------------------------------------------------
    tempSensor.requestTemperatures();
    float currentTemperature = tempSensor.getTempCByIndex(0);

    if (currentTemperature == DEVICE_DISCONNECTED_C) {
        Serial.println("[ERROR] DS18B20 Sensor Not Found! Using 25.0C Fallback.");
        currentTemperature = 25.0;
    }

    // ----------------------------------------------------
    // 2. READ DISSOLVED OXYGEN SENSOR
    // ----------------------------------------------------
    uint32_t rawDO = analogRead(DO_PIN);
    float voltageDO = (float)rawDO * VREF / ADC_RES;

    int doIndex = (int)round(currentTemperature);
    if (doIndex < 0) doIndex = 0;
    if (doIndex > 40) doIndex = 40;
    float maxSaturationDO = (float)DO_Table[doIndex] / 1000.0;

    float doValue = voltageDO * maxSaturationDO / cal1VoltageDO;

    // ----------------------------------------------------
    // 3. READ pH SENSOR
    // ----------------------------------------------------
    uint32_t rawPH = analogRead(PH_PIN);
    float voltagePH = (float)rawPH * VREF / ADC_RES;

    float slope = (7.0 - 4.0) / (phNeutralVoltage - phAcidVoltage);
    float phValue = 7.0 + (voltagePH - phNeutralVoltage) * slope;

    // ----------------------------------------------------
    // 4. PRINT LIVE INTEGRATED RESULTS
    // ----------------------------------------------------
    Serial.print("Temp: "); Serial.print(currentTemperature); Serial.print(" *C | ");
    Serial.print("DO: "); Serial.print(doValue); Serial.print(" mg/L | ");
    Serial.print("pH: "); Serial.println(phValue);

    postReading(currentTemperature, phValue, doValue);

    delay(2000);
}