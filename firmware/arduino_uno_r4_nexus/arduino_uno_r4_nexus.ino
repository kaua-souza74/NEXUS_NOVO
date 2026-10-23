#include <DHT.h>

constexpr uint8_t DHT_PIN = 2;
constexpr uint8_t LIGHT_PIN = A0;
constexpr uint8_t BUTTON_PIN = 4;
constexpr uint8_t DHT_TYPE = DHT11;
constexpr unsigned long SENSOR_INTERVAL_MS = 2500;
constexpr unsigned long DEBOUNCE_MS = 40;

DHT dht(DHT_PIN, DHT_TYPE);

bool presence = false;
bool rawButtonState = HIGH;
bool stableButtonState = HIGH;
unsigned long lastDebounceAt = 0;
unsigned long lastSensorReadAt = 0;

void updatePresenceButton(unsigned long now) {
  const bool reading = digitalRead(BUTTON_PIN);

  if (reading != rawButtonState) {
    rawButtonState = reading;
    lastDebounceAt = now;
  }

  if (now - lastDebounceAt >= DEBOUNCE_MS && reading != stableButtonState) {
    stableButtonState = reading;
    if (stableButtonState == LOW) {
      presence = !presence;
    }
  }
}

void emitTelemetry() {
  const float humidity = dht.readHumidity();
  const float temperature = dht.readTemperature();

  // DHT11 values are skipped until a valid sample is available.
  if (isnan(humidity) || isnan(temperature) || humidity < 0 || humidity > 100 || temperature < 0 || temperature > 50) {
    return;
  }

  const int lightRaw = analogRead(LIGHT_PIN);

  Serial.print(F("{\"temperature\":"));
  Serial.print(temperature, 1);
  Serial.print(F(",\"humidity\":"));
  Serial.print(humidity, 1);
  Serial.print(F(",\"presence\":"));
  Serial.print(presence ? F("true") : F("false"));
  Serial.print(F(",\"light\":"));
  Serial.print(lightRaw);
  Serial.println(F(",\"door_open\":false}"));
}

void setup() {
  Serial.begin(115200);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  analogReadResolution(10);

  rawButtonState = digitalRead(BUTTON_PIN);
  stableButtonState = rawButtonState;
  dht.begin();
}

void loop() {
  const unsigned long now = millis();
  updatePresenceButton(now);

  if (now - lastSensorReadAt >= SENSOR_INTERVAL_MS) {
    lastSensorReadAt = now;
    emitTelemetry();
  }
}
