import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { createAdminClient } from "../supabase/admin";

export const SENSOR_FIELDS = ["temperature", "humidity", "presence", "light", "door_open"] as const;

export type SensorPayload = {
  temperature: number;
  humidity: number;
  presence: boolean;
  light: number;
  door_open: boolean;
};

export type IngestResult =
  | { ok: true; deviceId: string; readingsPersisted: 5 }
  | { ok: false; reason: "invalid_payload" | "unauthorized" | "unavailable" | "persistence_failed" };

export type DeviceAuthentication =
  | { method: "token"; token: string }
  | { method: "mqtt_hmac"; timestamp: number; nonce: string; signature: string };

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function isSensorPayload(value: unknown): value is SensorPayload {
  if (!isRecord(value)) return false;
  const keys = Object.keys(value);
  if (keys.length !== SENSOR_FIELDS.length || !SENSOR_FIELDS.every((key) => key in value)) return false;

  return (
    typeof value.temperature === "number" && Number.isFinite(value.temperature) &&
    value.temperature >= -40 && value.temperature <= 80 &&
    typeof value.humidity === "number" && Number.isFinite(value.humidity) &&
    value.humidity >= 0 && value.humidity <= 100 &&
    typeof value.presence === "boolean" &&
    typeof value.light === "number" && Number.isFinite(value.light) && value.light >= 0 &&
    typeof value.door_open === "boolean"
  );
}

export function mqttSigningMessage(deviceId: string, timestamp: number, nonce: string, payload: SensorPayload) {
  return JSON.stringify([
    deviceId,
    timestamp,
    nonce,
    payload.temperature,
    payload.humidity,
    payload.presence,
    payload.light,
    payload.door_open,
  ]);
}

export function signMqttMessage(tokenHash: string, deviceId: string, timestamp: number, nonce: string, payload: SensorPayload) {
  return createHmac("sha256", Buffer.from(tokenHash, "hex"))
    .update(mqttSigningMessage(deviceId, timestamp, nonce, payload), "utf8")
    .digest("hex");
}

function safeHexEqual(value: string, expectedHex: string) {
  if (!/^[a-f\d]{64}$/i.test(value)) return false;
  const actual = Buffer.from(value, "hex");
  const expected = Buffer.from(expectedHex, "hex");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

export async function ingestDeviceReadings(
  deviceId: string,
  authentication: DeviceAuthentication,
  payload: unknown,
): Promise<IngestResult> {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(deviceId)) return { ok: false, reason: "unauthorized" };
  if (!isSensorPayload(payload)) return { ok: false, reason: "invalid_payload" };

  if (authentication.method === "token" && (authentication.token.length < 32 || authentication.token.length > 256)) {
    return { ok: false, reason: "unauthorized" };
  }
  if (authentication.method === "mqtt_hmac") {
    const now = Date.now();
    if (!Number.isSafeInteger(authentication.timestamp) || Math.abs(now - authentication.timestamp) > 60_000) {
      return { ok: false, reason: "unauthorized" };
    }
    if (!/^[A-Za-z0-9_-]{16,64}$/.test(authentication.nonce)) return { ok: false, reason: "unauthorized" };
  }

  let supabase;
  try {
    supabase = createAdminClient();
  } catch {
    return { ok: false, reason: "unavailable" };
  }

  const { data: device, error: deviceError } = await supabase
    .from("devices").select("id").eq("device_id", deviceId).maybeSingle();
  if (deviceError) return { ok: false, reason: "unavailable" };
  if (!device) return { ok: false, reason: "unauthorized" };

  const { data: credential, error: credentialError } = await supabase
    .from("device_credentials").select("token_hash").eq("device_id", device.id).is("revoked_at", null).maybeSingle();
  if (credentialError) return { ok: false, reason: "unavailable" };
  if (!credential || !/^[a-f\d]{64}$/i.test(credential.token_hash)) return { ok: false, reason: "unauthorized" };

  if (authentication.method === "token") {
    const tokenHash = createHash("sha256").update(authentication.token, "utf8").digest("hex");
    if (!safeHexEqual(tokenHash, credential.token_hash)) return { ok: false, reason: "unauthorized" };
  } else {
    const expectedSignature = signMqttMessage(
      credential.token_hash,
      deviceId,
      authentication.timestamp,
      authentication.nonce,
      payload,
    );
    if (!safeHexEqual(authentication.signature, expectedSignature)) return { ok: false, reason: "unauthorized" };
  }

  const { error: ingestError } = await supabase.rpc("ingest_device_readings", {
    p_device_uuid: device.id,
    p_temperature: payload.temperature,
    p_humidity: payload.humidity,
    p_presence: payload.presence,
    p_light: payload.light,
    p_door_open: payload.door_open,
  });
  if (ingestError) return { ok: false, reason: "persistence_failed" };
  return { ok: true, deviceId, readingsPersisted: 5 };
}
