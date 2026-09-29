#include <OneWire.h>
#include <DallasTemperature.h>
#include <WiFi.h>
#include <HTTPClient.h>

// ==========================================
// 🌐 NETWORK CONFIGURATION
// ==========================================
const char *WIFI_SSID = "SKYWORTH_AX_A2BB";
const char *WIFI_PASSWORD = "082303146";
const char *API_URL = "http://192.168.18.49:8000/api/readings";
const char *DEVICE_ID = "pond-1";
const char *DEVICE_KEY = "tp_pond1_dev_7f3c91a2d84e4b6f";

// ==========================================
// 📌 PIN CONFIGURATIONS
// ==========================================
#define DO_PIN    35       // Analog Pin for Dissolved Oxygen (D35)
#define PH_PIN    34       // Analog Pin for pH Sensor (D34)
#define ONE_WIRE_BUS 4     // Digital Pin for DS18B20 Temp Sensor (D4)

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

// DO Saturation Table (mg/L vs Temperature °C) from 0°C to 40°C
const uint16_t DO_Table[] = {
    14621, 14228, 13829, 13442, 13059, 12698, 12349, 12011, 11687, 11372,
    11071, 10777, 10495, 10221, 9956,  9700,  9453,  9213,  8981,  8757,
    8540,  8331,  8129,  7934,  7746,  7564,  7389,  7219,  7055,  6897,
    6744,  6596,  6453,  6314,  6180,  6050,  5923,  5801,  5682,  5567, 5456
};

void connectToWiFi() {
    if (WiFi.status() == WL_CONNECTED) return;

    Serial.print("Connecting to Wi-Fi");
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    for (uint8_t attempt = 0; attempt < 20 && WiFi.status() != WL_CONNECTED; attempt++) {
        delay(500);
        Serial.print(".");
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println();
        Serial.print("Wi-Fi connected. ESP32 IP: ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println(" failed");
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
    connectToWiFi();
    
    Serial.println("--- All 3 Sensors Initialized (DS18B20 Active) ---");
}

void loop() {
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