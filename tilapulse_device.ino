#include <OneWire.h>
#include <DallasTemperature.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiManager.h>   // https://github.com/tzapu/WiFiManager - install via Library Manager
#include <Preferences.h>

// ==========================================
// 🌐 NETWORK CONFIGURATION
// ==========================================
// WiFi credentials are no longer hardcoded. On first boot (or if saved
// credentials fail), the ESP32 opens its own setup access point named
// below. Connect a phone/laptop to it, a captive portal page will pop up
// automatically letting you pick your real WiFi network and enter its
// password. WiFiManager saves that to flash so this only needs to happen
// once per device (or after a reset - see resetWiFiSettings()).
const char *SETUP_AP_NAME = "TilaPulse-Setup";
// Optional: give the setup AP a password too, so a random passerby can't
// open your device's config portal. Leave as "" for an open setup AP.
const char *SETUP_AP_PASSWORD = "";

const char *API_URL = "http://192.168.18.49:8000/api/readings";
const char *DEVICE_ID = "pond-1";
const char *DEVICE_KEY = "stringst";

// ==========================================
// 📌 PIN CONFIGURATIONS
// ==========================================
#define DO_PIN    35       // Analog Pin for Dissolved Oxygen (D35)
#define PH_PIN    34       // Analog Pin for pH Sensor (D34)
#define ONE_WIRE_BUS 4     // Digital Pin for DS18B20 Temp Sensor (D4)
#define WIFI_RESET_PIN 0   // Hold this pin LOW at boot to wipe saved WiFi
                           // credentials and re-open the setup portal.
                           // On most ESP32 dev boards this is the "BOOT" button.

// ==========================================
// 🛠️ CALIBRATION VALUES
// ==========================================
#define VREF 3300.0        // ESP32 working voltage (3300mV)
#define ADC_RES 4096.0     // ESP32 12-bit ADC

// DO Calibration Values
float cal1VoltageDO = 1525.0; // Your unique air-saturated voltage (mV)

// pH Calibration Values (Standard DFRobot factory baseline)
float phNeutralVoltage = 1500.0; // Voltage at pH 7.0 (mV)
float phAcidVoltage    = 2032.0; // Voltage at pH 4.0 (mV)

// Initialize OneWire and DallasTemperature instances
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature tempSensor(&oneWire);
WiFiManager wm;

// DO Saturation Table (mg/L vs Temperature °C) from 0°C to 40°C
const uint16_t DO_Table[] = {
    14621, 14228, 13829, 13442, 13059, 12698, 12349, 12011, 11687, 11372,
    11071, 10777, 10495, 10221, 9956,  9700,  9453,  9213,  8981,  8757,
    8540,  8331,  8129,  7934,  7746,  7564,  7389,  7219,  7055,  6897,
    6744,  6596,  6453,  6314,  6180,  6050,  5923,  5801,  5682,  5567, 5456
};

// ==========================================
// 📶 WIFI PROVISIONING
// ==========================================
void resetWiFiSettingsIfRequested() {
    pinMode(WIFI_RESET_PIN, INPUT_PULLUP);
    delay(50); // let the pin settle
    if (digitalRead(WIFI_RESET_PIN) == LOW) {
        Serial.println("[WiFi] Reset pin held LOW at boot - erasing saved WiFi credentials.");
        wm.resetSettings();
    }
}

void connectToWiFi() {
    // Optional visual/serial feedback while the config portal is open.
    wm.setAPCallback([](WiFiManager *manager) {
        Serial.println("==================================================");
        Serial.print("[WiFi] No saved network found. Setup AP started: ");
        Serial.println(SETUP_AP_NAME);
        Serial.println("[WiFi] Connect a phone to that WiFi network, a setup");
        Serial.println("[WiFi] page should open automatically to configure it.");
        Serial.println("==================================================");
    });

    // How long the setup portal stays open before giving up and retrying
    // later (keeps the device from being stuck forever with no sensors
    // reporting if nobody configures it right away).
    wm.setConfigPortalTimeout(180); // 3 minutes

    bool connected;
    if (strlen(SETUP_AP_PASSWORD) > 0) {
        connected = wm.autoConnect(SETUP_AP_NAME, SETUP_AP_PASSWORD);
    } else {
        connected = wm.autoConnect(SETUP_AP_NAME);
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

void postReading(float currentTemperature, float phValue, float doValue) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[WARN] Reading not sent: Wi-Fi is disconnected.");
        return;
    }

    HTTPClient http;
    http.begin(API_URL);
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
    Serial.begin(115200); // Communication speed limit to laptop
    delay(1000);

    // Configure Analog Pins for ESP32
    pinMode(DO_PIN, ANALOG);
    pinMode(PH_PIN, ANALOG);
    analogReadResolution(12);

    // Initialize the DS18B20 Temp Sensor
    tempSensor.begin();

    resetWiFiSettingsIfRequested();
    connectToWiFi();

    Serial.println("--- All 3 Sensors Initialized (DS18B20 Active) ---");
}

void loop() {
    // If WiFi drops mid-operation (router reboot, out of range, etc.),
    // try to reconnect using the already-saved credentials rather than
    // re-opening the setup portal - the portal should only appear when
    // there are NO saved credentials at all, or resetWiFiSettings() ran.
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[WiFi] Connection lost, attempting to reconnect...");
        WiFi.reconnect();
        delay(2000);
    }

    // ----------------------------------------------------
    // 1. READ DIGITAL TEMPERATURE SENSOR (DS18B20)
    // ----------------------------------------------------
    tempSensor.requestTemperatures(); // Tell sensor to calculate a reading
    float currentTemperature = tempSensor.getTempCByIndex(0); // Fetch temperature in Celsius

    // Error Check: If sensor is physically unplugged or broken, it returns -127.0
    if (currentTemperature == DEVICE_DISCONNECTED_C) {
        Serial.println("[ERROR] DS18B20 Sensor Not Found! Using 25.0C Fallback.");
        currentTemperature = 25.0; // Temporary safety baseline value
    }

    // ----------------------------------------------------
    // 2. READ DISSOLVED OXYGEN SENSOR
    // ----------------------------------------------------
    uint32_t rawDO = analogRead(DO_PIN);
    float voltageDO = (float)rawDO * VREF / ADC_RES;

    // Use the dynamic live temperature to find the oxygen baseline step in array
    int doIndex = (int)round(currentTemperature);
    if (doIndex < 0) doIndex = 0;
    if (doIndex > 40) doIndex = 40; // Prevent exceeding array boundary limit
    float maxSaturationDO = (float)DO_Table[doIndex] / 1000.0;

    // Calculate accurate dynamic DO (mg/L) using the real-time temp
    float doValue = voltageDO * maxSaturationDO / cal1VoltageDO;

    // ----------------------------------------------------
    // 3. READ pH SENSOR
    // ----------------------------------------------------
    uint32_t rawPH = analogRead(PH_PIN);
    float voltagePH = (float)rawPH * VREF / ADC_RES;

    // Calculate pH using two-point slope mapping (Linear Interpolation)
    float slope = (7.0 - 4.0) / (phNeutralVoltage - phAcidVoltage);
    float phValue = 7.0 + (voltagePH - phNeutralVoltage) * slope;

    // ----------------------------------------------------
    // 4. PRINT LIVE INTEGRATED RESULTS
    // ----------------------------------------------------
    Serial.print("Temp: "); Serial.print(currentTemperature); Serial.print(" *C | ");
    Serial.print("DO: "); Serial.print(doValue); Serial.print(" mg/L | ");
    Serial.print("pH: "); Serial.println(phValue);

    postReading(currentTemperature, phValue, doValue);

    delay(2000); // Sample all parameters every 2 seconds
}