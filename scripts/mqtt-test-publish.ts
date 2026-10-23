import { randomBytes, createHash } from "node:crypto";
import "./load-local-env";
import mqtt from "mqtt";
import { signMqttMessage, type SensorPayload } from "../src/lib/iot/ingest";

const brokerUrl = process.env.MQTT_BROKER_URL ?? "mqtt://broker.emqx.io:1883";
const topic = process.env.MQTT_TOPIC ?? "nexus/vista-real/piscina/ESP32-001/readings";
const mode = process.argv[2] ?? "valid";
const deviceId = "ESP32-001";
const token = process.env.NEXUS_DEVICE_TOKEN_ESP32_001;
if (!token) throw new Error("NEXUS_DEVICE_TOKEN_ESP32_001 must be set in .env.local");

const payload: SensorPayload = {
  temperature: mode === "invalid-payload" ? 900 : 24.3,
  humidity: 61,
  presence: true,
  light: 723,
  door_open: false,
};
const timestamp = Date.now();
const nonce = randomBytes(18).toString("base64url");
const tokenHash = createHash("sha256").update(mode === "invalid-token" ? `${token}-wrong` : token, "utf8").digest("hex");
const envelope = {
  device_id: deviceId,
  timestamp,
  nonce,
  payload,
  signature: signMqttMessage(tokenHash, deviceId, timestamp, nonce, payload),
};

const client = mqtt.connect(brokerUrl, {
  clientId: `nexus-test-${randomBytes(6).toString("hex")}`,
  clean: true,
  connectTimeout: 15_000,
  reconnectPeriod: 0,
});

client.once("connect", () => {
  client.publish(topic, JSON.stringify(envelope), { qos: 0, retain: false }, (error) => {
    if (error) {
      console.error("MQTT publish failed", error.message);
      client.end(true, () => process.exit(1));
      return;
    }
    console.info(`MQTT test payload published (${mode}) to ${topic}`);
    client.end(false, () => process.exit(0));
  });
});

client.once("error", (error) => {
  console.error("MQTT test client error", error.message);
  client.end(true, () => process.exit(1));
});
