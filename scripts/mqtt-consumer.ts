import "./load-local-env";
import { randomUUID } from "node:crypto";
import mqtt from "mqtt";
import { ingestDeviceReadings, isRecord } from "../src/lib/iot/ingest";

const BROKER_URL = process.env.MQTT_BROKER_URL ?? "mqtt://broker.emqx.io:1883";
const TOPIC_FILTER = process.env.MQTT_SUBSCRIBE_TOPIC ?? "nexus/vista-real/+/+/readings";
const DEVICE_TOPICS = new Map([
  ["ESP32-001", "nexus/vista-real/piscina/ESP32-001/readings"],
  ["ESP32-00", "nexus/vista-real/sala-de-testes/ESP32-00/readings"],
]);
const MAX_MESSAGE_BYTES = 4096;
const MAX_NONCES = 10_000;
const seenNonces = new Map<string, number>();

type MqttEnvelope = {
  device_id: string;
  timestamp: number;
  nonce: string;
  payload: unknown;
  signature: string;
};

function isEnvelope(value: unknown): value is MqttEnvelope {
  return isRecord(value) &&
    typeof value.device_id === "string" &&
    typeof value.timestamp === "number" &&
    typeof value.nonce === "string" &&
    typeof value.signature === "string" &&
    "payload" in value;
}

const client = mqtt.connect(BROKER_URL, {
  clientId: `nexus-consumer-${randomUUID().slice(0, 12)}`,
  clean: true,
  connectTimeout: 15_000,
  keepalive: 30,
  reconnectPeriod: 3_000,
  protocolVersion: 4,
});

client.on("connect", () => {
  console.info("[NEXUS:MQTT] Connected");
  client.subscribe(TOPIC_FILTER, { qos: 0 }, (error) => {
    if (error) {
      console.error("[NEXUS:MQTT] Subscribe failed", error.message);
      return;
    }
    console.info(`[NEXUS:MQTT] Subscribed: ${TOPIC_FILTER}`);
  });
});

client.on("message", async (topic, message) => {
  console.info("[NEXUS:MQTT] Message received");
  if (message.byteLength > MAX_MESSAGE_BYTES) {
    console.warn("[NEXUS:MQTT] Invalid payload: message too large");
    return;
  }

  let envelope: unknown;
  try {
    envelope = JSON.parse(message.toString("utf8"));
  } catch {
    console.warn("[NEXUS:MQTT] Invalid payload: invalid JSON");
    return;
  }
  if (
    !isEnvelope(envelope) ||
    DEVICE_TOPICS.get(envelope.device_id) !== topic
  ) {
    console.warn("[NEXUS:MQTT] Invalid envelope or device ID");
    return;
  }

  const now = Date.now();
  for (const [nonceKey, expiresAt] of seenNonces) {
    if (expiresAt <= now) seenNonces.delete(nonceKey);
  }
  const nonceKey = `${envelope.device_id}:${envelope.nonce}`;
  if (seenNonces.has(nonceKey)) {
    console.warn("[NEXUS:MQTT] Replayed message rejected");
    return;
  }

  const result = await ingestDeviceReadings(
    envelope.device_id,
    {
      method: "mqtt_hmac",
      timestamp: envelope.timestamp,
      nonce: envelope.nonce,
      signature: envelope.signature,
    },
    envelope.payload,
  );

  if (!result.ok) {
    console.warn(`[NEXUS:MQTT] Message rejected: ${result.reason}`);
    return;
  }

  seenNonces.set(nonceKey, envelope.timestamp + 60_000);
  if (seenNonces.size > MAX_NONCES) seenNonces.delete(seenNonces.keys().next().value!);
  console.info(`[NEXUS:MQTT] Device authenticated: ${result.deviceId}`);
  console.info(`[NEXUS:MQTT] ${result.readingsPersisted} readings persisted`);
});

client.on("reconnect", () => console.info("[NEXUS:MQTT] Reconnecting"));
client.on("close", () => console.info("[NEXUS:MQTT] Connection closed"));
client.on("error", (error) => console.error("[NEXUS:MQTT] Client error", error.message));

function shutdown() {
  client.end(false, {}, () => process.exit(0));
}
process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
