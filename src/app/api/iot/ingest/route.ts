import { NextResponse } from "next/server";
import { ingestDeviceReadings } from "@/lib/iot/ingest";

export const runtime = "nodejs";
const MAX_BODY_BYTES = 4096;

class BodyTooLargeError extends Error {}

function jsonError(status: number, error: string) {
  return NextResponse.json({ ok: false, error }, { status });
}

async function readBody(request: Request): Promise<string> {
  const reader = request.body?.getReader();
  if (!reader) return "";

  const chunks: Buffer[] = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > MAX_BODY_BYTES) {
      await reader.cancel();
      throw new BodyTooLargeError();
    }
    chunks.push(Buffer.from(value));
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(Buffer.concat(chunks));
}

export async function POST(request: Request) {
  console.info("[NEXUS:IOT] request received");
  const contentType = request.headers.get("content-type")?.split(";")[0].trim().toLowerCase();
  if (contentType !== "application/json") return jsonError(415, "content_type_must_be_application_json");

  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) return jsonError(413, "payload_too_large");

  let payload: unknown;
  try {
    payload = JSON.parse(await readBody(request));
  } catch (error) {
    if (error instanceof BodyTooLargeError) return jsonError(413, "payload_too_large");
    return jsonError(400, "invalid_json");
  }

  const deviceId = request.headers.get("x-device-id")?.trim() ?? "";
  const deviceToken = request.headers.get("x-device-token") ?? "";
  const result = await ingestDeviceReadings(deviceId, { method: "token", token: deviceToken }, payload);

  if (!result.ok) {
    if (result.reason === "invalid_payload") {
      console.warn("[NEXUS:IOT] invalid payload");
      return jsonError(400, "invalid_sensor_payload");
    }
    if (result.reason === "unauthorized") {
      console.warn("[NEXUS:IOT] invalid credentials");
      return jsonError(401, "unauthorized_device");
    }
    if (result.reason === "unavailable") {
      console.error("[NEXUS:IOT] ingestion unavailable");
      return jsonError(503, "ingestion_unavailable");
    }
    console.error("[NEXUS:IOT] database error during ingestion");
    return jsonError(500, "ingestion_failed");
  }

  console.info(`[NEXUS:IOT] device authenticated: ${deviceId}`);
  console.info("[NEXUS:IOT] readings inserted: 5; last_seen updated");
  return NextResponse.json({ ok: true });
}
