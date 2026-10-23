/*
 * NEXUS physical node ESP32-00
 * Hardware: classic ESP32 Dev Module, DHT11, analog LDR module,
 *           and a 3-pin button module used to simulate presence.
 *
 * The HMAC canonical message intentionally uses integer sensor values so its
 * JSON number formatting is identical to Node's JSON.stringify().
 */

#include <Arduino.h>
#include <ArduinoMqttClient.h>
#include <cstring>
#include <DHT.h>
#include <WiFi.h>
#include <esp_random.h>
#include <mbedtls/md.h>
#include <time.h>

#include "arduino_secrets.h"

namespace {
constexpr char DEVICE_ID[] = "ESP32-00";
constexpr char BROKER_HOST[] = "broker.emqx.io";
constexpr uint16_t BROKER_PORT = 1883;
constexpr char MQTT_TOPIC[] = "nexus/vista-real/sala-de-testes/ESP32-00/readings";

constexpr uint8_t DHT_PIN = 4;
constexpr uint8_t LIGHT_PIN = 34;
constexpr uint8_t PRESENCE_PIN = 27;
constexpr uint8_t PRESENCE_ACTIVE_LEVEL = HIGH;

constexpr uint32_t PUBLISH_INTERVAL_MS = 10000;
constexpr uint32_t RECONNECT_INTERVAL_MS = 5000;
constexpr time_t MIN_VALID_EPOCH = 1700000000;

DHT dht(DHT_PIN, DHT11);
WiFiClient networkClient;
MqttClient mqttClient(networkClient);
uint32_t lastPublishAt = 0;
uint32_t lastReconnectAt = 0;

String boolJson(bool value) { return value ? "true" : "false"; }

bool deviceTokenConfigured() {
  return strlen(NEXUS_DEVICE_TOKEN) >= 32 &&
         strcmp(NEXUS_DEVICE_TOKEN, "YOUR_ESP32_00_DEVICE_TOKEN") != 0;
}

String newNonce() {
  uint8_t randomBytes[16];
  esp_fill_random(randomBytes, sizeof(randomBytes));
  static constexpr char HEX_DIGITS[] = "0123456789abcdef";
  char nonce[sizeof(randomBytes) * 2 + 1];
  for (size_t i = 0; i < sizeof(randomBytes); ++i) {
    nonce[i * 2] = HEX_DIGITS[randomBytes[i] >> 4];
    nonce[i * 2 + 1] = HEX_DIGITS[randomBytes[i] & 0x0F];
  }
  nonce[sizeof(nonce) - 1] = '\0';
  return String(nonce);
}

bool tokenHash(uint8_t output[32]) {
  const auto *info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  if (info == nullptr) return false;

  mbedtls_md_context_t context;
  mbedtls_md_init(&context);
  const int setup = mbedtls_md_setup(&context, info, 0);
  const int start = setup == 0 ? mbedtls_md_starts(&context) : setup;
  const int update = start == 0
                         ? mbedtls_md_update(
                               &context,
                               reinterpret_cast<const unsigned char *>(NEXUS_DEVICE_TOKEN),
                               strlen(NEXUS_DEVICE_TOKEN))
                         : start;
  const int finish = update == 0 ? mbedtls_md_finish(&context, output) : update;
  mbedtls_md_free(&context);
  return finish == 0;
}

bool hmacSha256Hex(const String &message, char output[65]) {
  uint8_t hashedToken[32];
  uint8_t digest[32];
  if (!tokenHash(hashedToken)) return false;

  const auto *info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  if (info == nullptr) return false;

  mbedtls_md_context_t context;
  mbedtls_md_init(&context);
  const int setup = mbedtls_md_setup(&context, info, 1);
  const int start = setup == 0
                       ? mbedtls_md_hmac_starts(&context, hashedToken, sizeof(hashedToken))
                       : setup;
  const int update = start == 0
                         ? mbedtls_md_hmac_update(
                               &context,
                               reinterpret_cast<const unsigned char *>(message.c_str()),
                               message.length())
                         : start;
  const int finish = update == 0
                         ? mbedtls_md_hmac_finish(&context, digest)
                         : update;
  mbedtls_md_free(&context);
  if (finish != 0) return false;

  static constexpr char HEX_DIGITS[] = "0123456789abcdef";
  for (size_t i = 0; i < sizeof(digest); ++i) {
    output[i * 2] = HEX_DIGITS[digest[i] >> 4];
    output[i * 2 + 1] = HEX_DIGITS[digest[i] & 0x0F];
  }
  output[64] = '\0';
  return true;
}

String makeCanonicalMessage(const String &timestamp, const String &nonce,
                            int temperature, int humidity, bool presence,
                            int light, bool doorOpen) {
  return String("[\"") + DEVICE_ID + "\"," + timestamp + ",\"" + nonce +
         "\"," + String(temperature) + "," + String(humidity) + "," +
         boolJson(presence) + "," + String(light) + "," + boolJson(doorOpen) +
         "]";
}

bool readSensors(int &temperature, int &humidity, bool &presence, int &light,
                 bool &doorOpen) {
  const float temperatureC = dht.readTemperature();
  const float relativeHumidity = dht.readHumidity();
  if (!isfinite(temperatureC) || !isfinite(relativeHumidity)) {
    Serial.println("[NEXUS:ESP32] DHT11 sem leitura válida; publicação ignorada");
    return false;
  }

  temperature = static_cast<int>(lroundf(temperatureC));
  humidity = static_cast<int>(lroundf(relativeHumidity));
  if (temperature < -50 || temperature > 100 || humidity < 0 || humidity > 100) {
    Serial.println("[NEXUS:ESP32] DHT11 fora dos limites; publicação ignorada");
    return false;
  }

  presence = digitalRead(PRESENCE_PIN) == PRESENCE_ACTIVE_LEVEL;
  light = analogRead(LIGHT_PIN);
  // The API contract still requires door_open; no physical door sensor is used.
  doorOpen = false;
  return true;
}

bool publishReading() {
  int temperature = 0;
  int humidity = 0;
  int light = 0;
  bool presence = false;
  bool doorOpen = false;
  if (!readSensors(temperature, humidity, presence, light, doorOpen)) return false;

  if (!deviceTokenConfigured()) {
    Serial.printf("[NEXUS:ESP32] Sensores OK · temp=%d C · umidade=%d%% · presença=%s · luz=%d raw · MQTT aguardando token exclusivo\n",
                  temperature, humidity, presence ? "sim" : "não", light);
    return false;
  }

  const time_t epochSeconds = time(nullptr);
  if (epochSeconds < MIN_VALID_EPOCH) {
    Serial.println("[NEXUS:ESP32] Aguardando horário NTP válido");
    return false;
  }

  char timestampBuffer[24];
  snprintf(timestampBuffer, sizeof(timestampBuffer), "%llu",
           static_cast<unsigned long long>(epochSeconds) * 1000ULL);
  const String timestamp(timestampBuffer);
  const String nonce = newNonce();
  const String canonical = makeCanonicalMessage(
      timestamp, nonce, temperature, humidity, presence, light, doorOpen);

  char signature[65];
  if (!hmacSha256Hex(canonical, signature)) {
    Serial.println("[NEXUS:ESP32] Erro ao calcular HMAC; publicação ignorada");
    return false;
  }

  const String json =
      String("{\"device_id\":\"") + DEVICE_ID + "\",\"timestamp\":" +
      timestamp + ",\"nonce\":\"" + nonce + "\",\"payload\":{" +
      "\"temperature\":" + String(temperature) +
      ",\"humidity\":" + String(humidity) +
      ",\"presence\":" + boolJson(presence) +
      ",\"light\":" + String(light) +
      ",\"door_open\":" + boolJson(doorOpen) +
      "},\"signature\":\"" + signature + "\"}";

  if (!mqttClient.connected()) return false;
  if (!mqttClient.beginMessage(MQTT_TOPIC, json.length(), false, 0)) {
    Serial.println("[NEXUS:ESP32] MQTT não iniciou publicação");
    return false;
  }
  mqttClient.print(json);
  if (!mqttClient.endMessage()) {
    Serial.println("[NEXUS:ESP32] Falha ao publicar no broker");
    return false;
  }

  Serial.printf("[NEXUS:ESP32] Publicado · temp=%d C · umidade=%d%% · presença=%s · luz=%d raw\n",
                temperature, humidity, presence ? "sim" : "não", light);
  return true;
}

void setUniqueMqttClientId() {
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toLowerCase();
  mqttClient.setId(String("NEXUS-") + DEVICE_ID + "-" + mac);
  mqttClient.setKeepAliveInterval(30000);
  mqttClient.setConnectionTimeout(10000);
}

}  // namespace

void setup() {
  Serial.begin(115200);
  delay(250);
  Serial.println("\n[NEXUS:ESP32] Iniciando ESP32-00 físico");

  pinMode(PRESENCE_PIN, INPUT_PULLDOWN);
  analogReadResolution(12);
  analogSetPinAttenuation(LIGHT_PIN, ADC_11db);
  dht.begin();

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("[NEXUS:ESP32] Conectando ao Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print('.');
  }
  Serial.printf("\n[NEXUS:ESP32] Wi-Fi conectado · IP %s\n",
                WiFi.localIP().toString().c_str());

  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  setUniqueMqttClientId();
  Serial.printf("[NEXUS:ESP32] MQTT %s:%u · tópico %s\n",
                BROKER_HOST, BROKER_PORT, MQTT_TOPIC);
}

void loop() {
  const uint32_t now = millis();

  if (WiFi.status() != WL_CONNECTED) {
    if (now - lastReconnectAt >= RECONNECT_INTERVAL_MS) {
      lastReconnectAt = now;
      Serial.println("[NEXUS:ESP32] Wi-Fi desconectado; reconectando");
      WiFi.reconnect();
    }
    delay(20);
    return;
  }

  if (!mqttClient.connected() && now - lastReconnectAt >= RECONNECT_INTERVAL_MS) {
    lastReconnectAt = now;
    Serial.println("[NEXUS:ESP32] Conectando ao broker MQTT");
    if (mqttClient.connect(BROKER_HOST, BROKER_PORT)) {
      Serial.println("[NEXUS:ESP32] MQTT conectado");
    } else {
      Serial.printf("[NEXUS:ESP32] MQTT falhou · código %d\n",
                    mqttClient.connectError());
    }
  }

  mqttClient.poll();

  if (mqttClient.connected() && now - lastPublishAt >= PUBLISH_INTERVAL_MS) {
    lastPublishAt = now;
    publishReading();
  }
  delay(10);
}
