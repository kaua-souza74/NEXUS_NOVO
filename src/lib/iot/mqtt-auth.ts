import { createHmac } from "node:crypto";

export type SensorPayloadInput = {
  temperature: number;
  humidity: number;
  presence: boolean;
  light: number;
  door_open: boolean;
};

export function mqttSigningMessage(
  deviceId: string,
  timestamp: number,
  nonce: string,
  payload: SensorPayloadInput,
): string {
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


export function signMqttMessage(
  tokenHash: string,
  deviceId: string,
  timestamp: number,
  nonce: string,
  payload: SensorPayloadInput,
): string;
export function signMqttMessage(
  tokenHash: string,
  deviceId: string,
  timestamp: number,
  nonce: string,
  temperature: number,
  humidity: number,
  presence: boolean,
  light: number,
  door_open: boolean,
): string;
export function signMqttMessage(
  tokenHash: string,
  deviceId: string,
  timestamp: number,
  nonce: string,
  payloadOrTemperature: SensorPayloadInput | number,
  humidity?: number,
  presence?: boolean,
  light?: number,
  door_open?: boolean,
): string {
  let payload: SensorPayloadInput;

  if (typeof payloadOrTemperature === "object" && payloadOrTemperature !== null) {
    payload = payloadOrTemperature;
  } else {
    payload = {
      temperature: payloadOrTemperature,
      humidity: humidity ?? 0,
      presence: Boolean(presence),
      light: light ?? 0,
      door_open: Boolean(door_open),
    };
  }

  const message = mqttSigningMessage(deviceId, timestamp, nonce, payload);

  return createHmac("sha256", Buffer.from(tokenHash, "hex"))
    .update(message, "utf8")
    .digest("hex");
}
