import assert from "node:assert/strict";
import { createHash, createHmac } from "node:crypto";
import test from "node:test";

import {
  createSignedMqttEnvelope,
  DEVICE_ID,
  EXPECTED_TOPIC,
  isAllowedDeviceTopic,
  ONCE_PUBLICATION_TOPIC,
  parseArduinoTelemetryLine,
} from "./arduino-serial-protocol";
import { parseBridgeOptions } from "./arduino-serial-bridge-options";
import { mqttSigningMessage, signMqttMessage } from "../src/lib/iot/mqtt-auth";

const validLine =
  '{"temperature":23.4,"humidity":51,"presence":true,"light":486,"door_open":false}';

test("parses a complete Arduino JSON line", () => {
  assert.deepEqual(parseArduinoTelemetryLine(validLine), {
    temperature: 23.4,
    humidity: 51,
    presence: true,
    light: 486,
    door_open: false,
  });
});

test("rejects invalid JSON, missing fields, and unknown fields", () => {
  assert.throws(() => parseArduinoTelemetryLine("not-json"));
  assert.throws(() =>
    parseArduinoTelemetryLine('{"temperature":23,"humidity":50,"presence":false,"light":2}'),
  );
  assert.throws(() =>
    parseArduinoTelemetryLine(
      '{"temperature":23,"humidity":50,"presence":false,"light":2,"door_open":false,"extra":1}',
    ),
  );
});

test("rejects values outside the board and database contract", () => {
  assert.throws(() =>
    parseArduinoTelemetryLine(validLine.replace('"temperature":23.4', '"temperature":81')),
  );
  assert.throws(() =>
    parseArduinoTelemetryLine(validLine.replace('"humidity":51', '"humidity":101')),
  );
  assert.throws(() =>
    parseArduinoTelemetryLine(validLine.replace('"light":486', '"light":1024')),
  );
  assert.throws(() =>
    parseArduinoTelemetryLine(validLine.replace('"door_open":false', '"door_open":true')),
  );
});

test("parses the single-publication COM12 command without enabling dry-run", () => {
  assert.deepEqual(parseBridgeOptions(["--port", "COM12", "--once"]), {
    dryRun: false,
    once: true,
    port: "COM12",
    help: false,
  });
  assert.deepEqual(parseBridgeOptions(["--port", "COM12", "--once", "--dry-run"]), {
    dryRun: true,
    once: true,
    port: "COM12",
    help: false,
  });
});

test("allows the requested one-shot topic while preserving the existing device topic", () => {
  assert.equal(isAllowedDeviceTopic(DEVICE_ID, ONCE_PUBLICATION_TOPIC), true);
  assert.equal(isAllowedDeviceTopic(DEVICE_ID, EXPECTED_TOPIC), true);
  assert.equal(
    isAllowedDeviceTopic(DEVICE_ID, "nexus/vista-real/outro/ESP32-001/readings"),
    false,
  );
  assert.equal(
    isAllowedDeviceTopic(
      "ESP32-00",
      "nexus/vista-real/sala-de-testes/ESP32-00/readings",
    ),
    false,
  );
});

test("uses the consumer's canonical HMAC-SHA256 signing contract", () => {
  const payload = parseArduinoTelemetryLine(validLine);
  const tokenHash = createHash("sha256").update("a-local-test-token-used-only-by-unit-tests", "utf8").digest("hex");
  const timestamp = 1_800_000_000_000;
  const nonce = "abcdefghijklmnopqrstuvwx";
  const message = JSON.stringify([
    DEVICE_ID,
    timestamp,
    nonce,
    payload.temperature,
    payload.humidity,
    payload.presence,
    payload.light,
    payload.door_open,
  ]);
  const expectedSignature = createHmac("sha256", Buffer.from(tokenHash, "hex"))
    .update(message, "utf8")
    .digest("hex");

  assert.equal(mqttSigningMessage(DEVICE_ID, timestamp, nonce, payload), message);
  assert.equal(signMqttMessage(tokenHash, DEVICE_ID, timestamp, nonce, payload) === expectedSignature, true);
});

test("builds the consumer envelope without changing the payload contract", () => {
  const payload = parseArduinoTelemetryLine(validLine);
  const envelope = createSignedMqttEnvelope(
    payload,
    "a-local-test-token-used-only-by-unit-tests",
    1_800_000_000_000,
    "abcdefghijklmnopqrstuvwx",
  );

  assert.deepEqual(Object.keys(envelope).sort(), [
    "device_id",
    "nonce",
    "payload",
    "signature",
    "timestamp",
  ]);
  assert.equal(envelope.device_id, DEVICE_ID);
  assert.equal(envelope.payload, payload);
  assert.equal(/^[a-f\d]{64}$/i.test(envelope.signature), true);
});
