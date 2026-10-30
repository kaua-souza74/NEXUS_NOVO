import { createHash, randomBytes } from "node:crypto";

import type { SensorPayload } from "../src/lib/iot/ingest";
import { signMqttMessage } from "../src/lib/iot/mqtt-auth";

export const DEVICE_ID = "ESP32-001";
export const MAX_SERIAL_LINE_BYTES = 4096;
export const EXPECTED_TOPIC = `nexus/vista-real/piscina/${DEVICE_ID}/readings`;
export const ONCE_PUBLICATION_TOPIC = `nexus/vista-real/quarto-101/${DEVICE_ID}/readings`;
const ACCEPTED_TOPICS_BY_DEVICE = new Map<string, ReadonlySet<string>>([
  [DEVICE_ID, new Set([EXPECTED_TOPIC, ONCE_PUBLICATION_TOPIC])],
]);

export function isAllowedDeviceTopic(deviceId: string, topic: string): boolean {
  return ACCEPTED_TOPICS_BY_DEVICE.get(deviceId)?.has(topic) ?? false;
}

const REQUIRED_FIELDS = [
  "door_open",
  "humidity",
  "light",
  "presence",
  "temperature",
] as const;

export type MqttEnvelope = {
  device_id: string;
  timestamp: number;
  nonce: string;
  payload: SensorPayload;
  signature: string;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function parseArduinoTelemetryLine(line: string): SensorPayload {
  if (Buffer.byteLength(line, "utf8") > MAX_SERIAL_LINE_BYTES) {
    throw new Error("linha serial excede o limite de tamanho");
  }

  let decoded: unknown;
  try {
    decoded = JSON.parse(line.trim());
  } catch {
    throw new Error("linha serial não contém JSON válido");
  }

  if (!isRecord(decoded)) {
    throw new Error("telemetria deve ser um objeto JSON");
  }

  const actualFields = Object.keys(decoded).sort();
  if (
    actualFields.length !== REQUIRED_FIELDS.length ||
    actualFields.some((field, index) => field !== REQUIRED_FIELDS[index])
  ) {
    throw new Error("telemetria deve conter exatamente os cinco campos esperados");
  }

  const { temperature, humidity, presence, light, door_open: doorOpen } = decoded;

  if (
    typeof temperature !== "number" ||
    !Number.isFinite(temperature) ||
    temperature < -40 ||
    temperature > 80
  ) {
    throw new Error("temperatura fora do intervalo aceito pelo NEXUS");
  }

  if (
    typeof humidity !== "number" ||
    !Number.isFinite(humidity) ||
    humidity < 0 ||
    humidity > 100
  ) {
    throw new Error("umidade deve estar entre 0 e 100 por cento");
  }

  if (typeof presence !== "boolean") {
    throw new Error("presença deve ser booleana");
  }

  if (
    typeof light !== "number" ||
    !Number.isInteger(light) ||
    light < 0 ||
    light > 1023
  ) {
    throw new Error("luminosidade raw deve ser um inteiro entre 0 e 1023");
  }

  if (doorOpen !== false) {
    throw new Error("o firmware desta placa deve reportar a porta fechada");
  }

  return {
    temperature,
    humidity,
    presence,
    light,
    door_open: false,
  };
}

export function createSignedMqttEnvelope(
  payload: SensorPayload,
  rawDeviceToken: string,
  timestamp = Date.now(),
  nonce = randomBytes(18).toString("base64url"),
): MqttEnvelope {
  if (
    typeof rawDeviceToken !== "string" ||
    rawDeviceToken.length < 32 ||
    rawDeviceToken.length > 256
  ) {
    throw new Error("token local do dispositivo ausente ou inválido");
  }

  if (!Number.isSafeInteger(timestamp)) {
    throw new Error("timestamp inválido");
  }

  if (!/^[A-Za-z0-9_-]{16,64}$/.test(nonce)) {
    throw new Error("nonce inválido");
  }

  const tokenHash = createHash("sha256")
    .update(rawDeviceToken, "utf8")
    .digest("hex");

  return {
    device_id: DEVICE_ID,
    timestamp,
    nonce,
    payload,
    signature: signMqttMessage(tokenHash, DEVICE_ID, timestamp, nonce, payload),
  };
}
