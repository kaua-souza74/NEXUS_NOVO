import { createHash } from "node:crypto";

import {
  signMqttMessage,
  mqttSigningMessage,
} from "./mqtt-auth";

import { createAdminClient } from "@/lib/supabase/admin";

export { signMqttMessage, mqttSigningMessage } from "./mqtt-auth";

export function isRecord(
  value: unknown,
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}

export type SensorPayload = {
  temperature: number;
  humidity: number;
  presence: boolean;
  light: number;
  door_open: boolean;
};

export type DeviceAuthentication =
  | {
    method: "token";
    token: string;
  }
  | {
    method: "mqtt_hmac";
    timestamp: number;
    nonce: string;
    signature: string;
  };

export type IngestResult =
  | {
    ok: true;
  }
  | {
    ok: false;
    reason:
    | "invalid_payload"
    | "unauthorized"
    | "unavailable"
    | "persistence_failed";
  };

export type IngestDeviceReadingInput = {
  deviceId: string;
  payload: SensorPayload;
  authentication: DeviceAuthentication;
};

function safeHexEqual(
  a: string,
  b: string,
): boolean {
  if (
    typeof a !== "string" ||
    typeof b !== "string" ||
    a.length !== b.length
  ) {
    return false;
  }

  let result = 0;

  for (let i = 0; i < a.length; i++) {
    result |=
      a.charCodeAt(i) ^
      b.charCodeAt(i);
  }

  return result === 0;
}

function isValidSensorPayload(
  payload: SensorPayload,
): boolean {
  if (
    !payload ||
    typeof payload !== "object"
  ) {
    return false;
  }

  if (
    typeof payload.temperature !== "number" ||
    !Number.isFinite(payload.temperature) ||
    payload.temperature < -50 ||
    payload.temperature > 100
  ) {
    return false;
  }

  if (
    typeof payload.humidity !== "number" ||
    !Number.isFinite(payload.humidity) ||
    payload.humidity < 0 ||
    payload.humidity > 100
  ) {
    return false;
  }

  if (
    typeof payload.presence !== "boolean"
  ) {
    return false;
  }

  if (
    typeof payload.light !== "number" ||
    !Number.isFinite(payload.light) ||
    payload.light < 0
  ) {
    return false;
  }

  if (
    typeof payload.door_open !== "boolean"
  ) {
    return false;
  }

  return true;
}

export async function ingestDeviceReading(
  {
    deviceId,
    payload,
    authentication,
  }: IngestDeviceReadingInput,
): Promise<IngestResult> {
  console.log(
    "[NEXUS:IOT] Starting ingestion:",
    {
      deviceId,
      authMethod: authentication?.method,
    },
  );

  /*
   * 1. Validação básica
   */

  if (
    typeof deviceId !== "string" ||
    deviceId.trim().length === 0 ||
    deviceId.length > 128
  ) {
    console.error(
      "[NEXUS:IOT] Invalid deviceId",
    );

    return {
      ok: false,
      reason: "invalid_payload",
    };
  }

  if (!isValidSensorPayload(payload)) {
    console.error(
      "[NEXUS:IOT] Invalid sensor payload:",
      payload,
    );

    return {
      ok: false,
      reason: "invalid_payload",
    };
  }

  if (
    !authentication ||
    typeof authentication !== "object"
  ) {
    console.error(
      "[NEXUS:IOT] Unauthorized: missing authentication",
    );

    return {
      ok: false,
      reason: "unauthorized",
    };
  }

  /*
   * 2. Validação token
   */

  if (
    authentication.method === "token"
  ) {
    if (
      typeof authentication.token !== "string" ||
      authentication.token.length < 32 ||
      authentication.token.length > 256
    ) {
      console.error(
        "[NEXUS:IOT] Unauthorized: invalid token format",
      );

      return {
        ok: false,
        reason: "unauthorized",
      };
    }
  }

  /*
   * 3. Validação MQTT/HMAC
   */

  if (
    authentication.method === "mqtt_hmac"
  ) {
    const now = Date.now();

    console.log(
      "[NEXUS:IOT] MQTT auth debug:",
      {
        server_time_ms: now,
        device_timestamp:
          authentication.timestamp,
        difference_ms:
          now -
          authentication.timestamp,
        difference_seconds:
          (
            (now -
              authentication.timestamp) /
            1000
          ),
        nonce:
          authentication.nonce,
        signature_length:
          typeof authentication.signature ===
            "string"
            ? authentication.signature.length
            : null,
      },
    );

    if (
      !Number.isSafeInteger(
        authentication.timestamp,
      )
    ) {
      console.error(
        "[NEXUS:IOT] Unauthorized: invalid timestamp",
      );

      return {
        ok: false,
        reason: "unauthorized",
      };
    }

    const timeDifference =
      Math.abs(
        now -
        authentication.timestamp,
      );

    if (
      timeDifference > 60_000
    ) {
      console.error(
        "[NEXUS:IOT] Unauthorized: timestamp outside ±60s window",
        {
          difference_ms:
            now -
            authentication.timestamp,
          difference_seconds:
            (
              (now -
                authentication.timestamp) /
              1000
            ),
        },
      );

      return {
        ok: false,
        reason: "unauthorized",
      };
    }

    if (
      typeof authentication.nonce !==
      "string" ||
      !/^[A-Za-z0-9_-]{16,64}$/.test(
        authentication.nonce,
      )
    ) {
      console.error(
        "[NEXUS:IOT] Unauthorized: invalid nonce",
        authentication.nonce,
      );

      return {
        ok: false,
        reason: "unauthorized",
      };
    }

    if (
      typeof authentication.signature !==
      "string" ||
      !/^[a-fA-F0-9]{64}$/.test(
        authentication.signature,
      )
    ) {
      console.error(
        "[NEXUS:IOT] Unauthorized: invalid signature format",
      );

      return {
        ok: false,
        reason: "unauthorized",
      };
    }
  }

  /*
   * 4. Criar client admin Supabase
   */

  let supabase;

  try {
    supabase = createAdminClient();
  } catch (error) {
    console.error(
      "[NEXUS:IOT] createAdminClient failed:",
      error,
    );

    return {
      ok: false,
      reason: "unavailable",
    };
  }

  /*
   * 5. Buscar device
   */

  const {
    data: device,
    error: deviceError,
  } = await supabase
    .from("devices")
    .select("id")
    .eq("device_id", deviceId)
    .maybeSingle();

  if (deviceError) {
    console.error(
      "[NEXUS:IOT] devices query failed:",
      deviceError,
    );

    return {
      ok: false,
      reason: "unavailable",
    };
  }

  if (!device) {
    console.error(
      "[NEXUS:IOT] Unauthorized: device not found:",
      deviceId,
    );

    return {
      ok: false,
      reason: "unauthorized",
    };
  }

  console.log(
    "[NEXUS:IOT] Device found:",
    device.id,
  );

  /*
   * 6. Buscar credencial ativa
   */

  const {
    data: credential,
    error: credentialError,
  } = await supabase
    .from("device_credentials")
    .select("token_hash")
    .eq("device_id", device.id)
    .is("revoked_at", null)
    .maybeSingle();

  if (credentialError) {
    console.error(
      "[NEXUS:IOT] device_credentials query failed:",
      credentialError,
    );

    return {
      ok: false,
      reason: "unavailable",
    };
  }

  if (!credential) {
    console.error(
      "[NEXUS:IOT] Unauthorized: no active credential",
    );

    return {
      ok: false,
      reason: "unauthorized",
    };
  }

  if (
    typeof credential.token_hash !==
    "string" ||
    !/^[a-f\d]{64}$/i.test(
      credential.token_hash,
    )
  ) {
    console.error(
      "[NEXUS:IOT] Unauthorized: invalid credential token_hash",
    );

    return {
      ok: false,
      reason: "unauthorized",
    };
  }

  console.log(
    "[NEXUS:IOT] Active credential found",
  );

  /*
   * 7. Autenticação real
   */

  if (
    authentication.method === "token"
  ) {
    const tokenHash =
      createHash("sha256")
        .update(
          authentication.token,
          "utf8",
        )
        .digest("hex");

    if (
      !safeHexEqual(
        tokenHash,
        credential.token_hash,
      )
    ) {
      console.error(
        "[NEXUS:IOT] Unauthorized: token mismatch",
      );

      return {
        ok: false,
        reason: "unauthorized",
      };
    }

    console.log(
      "[NEXUS:IOT] Token authentication PASS",
    );
  } else {
    /*
     * IMPORTANTE:
     * Aqui está o log que queríamos.
     */

    const signingMessage =
      mqttSigningMessage(
        deviceId,
        authentication.timestamp,
        authentication.nonce,
        payload,
      );

    console.log(
      "[NEXUS:IOT] Signing message:",
      signingMessage,
    );

    const expectedSignature =
      signMqttMessage(
        credential.token_hash,
        deviceId,
        authentication.timestamp,
        authentication.nonce,
        payload.temperature,
        payload.humidity,
        payload.presence,
        payload.light,
        payload.door_open,
      );

    console.log(
      "[NEXUS:IOT] HMAC debug:",
      {
        received_signature:
          authentication.signature,
        expected_signature:
          expectedSignature,
        match:
          safeHexEqual(
            expectedSignature,
            authentication.signature,
          ),
      },
    );

    if (
      !safeHexEqual(
        expectedSignature,
        authentication.signature,
      )
    ) {
      console.error(
        "[NEXUS:IOT] Unauthorized: HMAC mismatch",
      );

      return {
        ok: false,
        reason: "unauthorized",
      };
    }

    console.log(
      "[NEXUS:IOT] HMAC authentication PASS",
    );
  }

  /*
   * 8. Persistir leituras
   */

  const readings = [
    {
      device_id: device.id,
      sensor_type:
        "temperature",
      value_numeric:
        payload.temperature,
      value_boolean: null,
      unit: "°C",
    },

    {
      device_id: device.id,
      sensor_type:
        "humidity",
      value_numeric:
        payload.humidity,
      value_boolean: null,
      unit: "%",
    },

    {
      device_id: device.id,
      sensor_type:
        "presence",
      value_numeric: null,
      value_boolean:
        payload.presence,
      unit: null,
    },

    {
      device_id: device.id,
      sensor_type:
        "light",
      value_numeric:
        payload.light,
      value_boolean: null,
      unit: null,
    },

    {
      device_id: device.id,
      sensor_type:
        "door",
      value_numeric: null,
      value_boolean:
        payload.door_open,
      unit: null,
    },
  ];

  const {
    error: readingsError,
  } = await supabase
    .from("sensor_readings")
    .insert(readings);

  if (readingsError) {
    console.error(
      "[NEXUS:IOT] sensor_readings insert failed:",
      readingsError,
    );

    return {
      ok: false,
      reason: "persistence_failed",
    };
  }

  /*
   * 9. Atualizar last_seen
   */

  const {
    error: lastSeenError,
  } = await supabase
    .from("devices")
    .update({
      last_seen_at:
        new Date().toISOString(),
    })
    .eq("id", device.id);

  if (lastSeenError) {
    console.error(
      "[NEXUS:IOT] last_seen_at update failed:",
      lastSeenError,
    );

    return {
      ok: false,
      reason: "persistence_failed",
    };
  }

  console.log(
    "[NEXUS:IOT] Reading authenticated and persisted",
  );

  return {
    ok: true,
  };
}

export async function ingestDeviceReadings(
  deviceId: string,
  authentication: DeviceAuthentication,
  payload: unknown,
) {
  if (!isValidSensorPayload(payload as SensorPayload)) {
    return { ok: false, reason: "invalid_payload" as const };
  }

  const result = await ingestDeviceReading({
    deviceId,
    authentication,
    payload: payload as SensorPayload,
  });

  if (!result.ok) {
    return result;
  }

  return {
    ok: true as const,
    deviceId,
    readingsPersisted: 5,
  };
}