import "./load-local-env";

import mqtt, { type MqttClient } from "mqtt";
import { SerialPort } from "serialport";
import { ReadlineParser } from "@serialport/parser-readline";
import { Transform, type TransformCallback } from "node:stream";

import { parseBridgeOptions } from "./arduino-serial-bridge-options";
import {
  createSignedMqttEnvelope,
  EXPECTED_TOPIC,
  MAX_SERIAL_LINE_BYTES,
  ONCE_PUBLICATION_TOPIC,
  parseArduinoTelemetryLine,
} from "./arduino-serial-protocol";

const SERIAL_BAUD_RATE = 115200;
const DEFAULT_BROKER_URL = "mqtt://broker.emqx.io:1883";

class BoundedLineGuard extends Transform {
  private pending: Buffer[] = [];
  private pendingBytes = 0;
  private discardingLine = false;

  constructor(private readonly maxLineBytes: number) {
    super();
  }

  _transform(
    chunk: Buffer,
    _encoding: BufferEncoding,
    callback: TransformCallback,
  ): void {
    let offset = 0;

    while (offset < chunk.length) {
      const newline = chunk.indexOf(0x0a, offset);
      const segmentEnd = newline === -1 ? chunk.length : newline;
      const segment = chunk.subarray(offset, segmentEnd);

      if (!this.discardingLine) {
        if (this.pendingBytes + segment.length > this.maxLineBytes) {
          this.pending = [];
          this.pendingBytes = 0;
          this.discardingLine = true;
          this.emit("lineTooLong");
        } else if (segment.length > 0) {
          this.pending.push(segment);
          this.pendingBytes += segment.length;
        }
      }

      if (newline === -1) {
        break;
      }

      if (!this.discardingLine) {
        const line = Buffer.concat(this.pending, this.pendingBytes + 1);
        line[line.length - 1] = 0x0a;
        this.push(line);
      }

      this.pending = [];
      this.pendingBytes = 0;
      this.discardingLine = false;
      offset = newline + 1;
    }

    callback();
  }

  _flush(callback: TransformCallback): void {
    this.pending = [];
    this.pendingBytes = 0;
    callback();
  }
}

function printHelp(): void {
  console.info("Uso: npm run arduino:bridge:dry-run -- --port COM11");
  console.info("Publicação única (QoS 1): npm run arduino:bridge -- --port COM12 --once");
  console.info("Fluxo contínuo: npm run arduino:bridge -- --port COM11");
  console.info("Adicione --dry-run --once para validar só a primeira linha sem MQTT.");
  console.info("Feche o Monitor Serial do Arduino IDE antes de iniciar.");
}

function main(): Promise<void> {
  const options = parseBridgeOptions(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return Promise.resolve();
  }

  const token = process.env.NEXUS_DEVICE_TOKEN_ESP32_001;
  if (!token || token.length < 32 || token.length > 256) {
    throw new Error("configure NEXUS_DEVICE_TOKEN_ESP32_001 em .env.local");
  }

  const brokerUrl = process.env.MQTT_BROKER_URL ?? DEFAULT_BROKER_URL;
  if (!/^mqtts?:\/\//i.test(brokerUrl)) {
    throw new Error("MQTT_BROKER_URL deve usar mqtt:// ou mqtts://");
  }

  const topic = options.once
    ? ONCE_PUBLICATION_TOPIC
    : process.env.MQTT_TOPIC ?? EXPECTED_TOPIC;
  if (!options.once && topic !== EXPECTED_TOPIC) {
    throw new Error("MQTT_TOPIC não corresponde ao dispositivo ESP32-001 cadastrado");
  }

  const serial = new SerialPort({
    path: options.port,
    baudRate: SERIAL_BAUD_RATE,
    autoOpen: false,
  });
  const lineGuard = new BoundedLineGuard(MAX_SERIAL_LINE_BYTES);
  const parser = new ReadlineParser({ delimiter: "\n", encoding: "utf8" });
  let client: MqttClient | undefined;
  let stopping = false;
  let connected = false;
  let onceClaimed = false;
  let oncePublishStarted = false;

  lineGuard.on("lineTooLong", () => {
    console.warn("[NEXUS:BRIDGE] Linha serial descartada: excedeu 4096 bytes");
  });

  serial.pipe(lineGuard).pipe(parser);

  return new Promise<void>((resolve, reject) => {
    const closeSerial = (done: () => void) => {
      if (serial.isOpen) serial.close(() => done());
      else done();
    };

    const shutdown = (errorMessage?: string) => {
      if (stopping) return;
      stopping = true;
      if (errorMessage) {
        console.error(`[NEXUS:BRIDGE] ${errorMessage}`);
        process.exitCode = 1;
      }
      if (client) {
        client.end(Boolean(errorMessage), {}, () => closeSerial(resolve));
      } else {
        closeSerial(resolve);
      }
    };

    process.once("SIGINT", () => shutdown());
    process.once("SIGTERM", () => shutdown());

    const publishOnce = (envelope: ReturnType<typeof createSignedMqttEnvelope>) => {
      if (oncePublishStarted || stopping) return;
      oncePublishStarted = true;

      try {
        client = mqtt.connect(brokerUrl, {
          clientId: `nexus-arduino-once-${process.pid}`,
          clean: true,
          connectTimeout: 15_000,
          keepalive: 30,
          reconnectPeriod: 0,
          protocolVersion: 4,
        });
      } catch {
        shutdown("não foi possível iniciar a conexão MQTT; nenhuma repetição será feita");
        return;
      }

      client.once("connect", () => {
        connected = true;
        console.info("[NEXUS:BRIDGE] Conectada ao broker; enviando publicação única QoS 1");
        client!.publish(
          topic,
          JSON.stringify(envelope),
          { qos: 1, retain: false },
          (error) => {
            if (error) {
              shutdown("callback MQTT confirmou falha; publicação não será repetida");
              return;
            }
            console.info("[NEXUS:BRIDGE] Callback MQTT QoS 1 confirmado");
            shutdown();
          },
        );
      });

      client.on("close", () => {
        connected = false;
        if (!stopping) {
          shutdown("conexão MQTT encerrou antes da confirmação; publicação não será repetida");
        }
      });
      client.on("error", () => {
        connected = false;
        if (!stopping) {
          shutdown("falha MQTT antes da confirmação; publicação não será repetida");
        }
      });
    };

    parser.on("data", (line: string) => {
      if (stopping || (options.once && onceClaimed)) return;

      let payload;
      try {
        payload = parseArduinoTelemetryLine(line);
      } catch (error) {
        const reason = error instanceof Error ? error.message : "JSON inválido";
        console.warn(`[NEXUS:BRIDGE] Linha descartada: ${reason}`);
        return;
      }

      if (options.once) onceClaimed = true;

      let envelope;
      try {
        envelope = createSignedMqttEnvelope(payload, token);
      } catch {
        shutdown("não foi possível preparar a autenticação MQTT");
        return;
      }

      if (options.dryRun) {
        console.info(
          `[NEXUS:BRIDGE] Dry-run validado: temperatura ${payload.temperature} °C, ` +
            `umidade ${payload.humidity}%, presença ${payload.presence ? "sim" : "não"}, ` +
            `luminosidade raw ${payload.light}; MQTT desativado.`,
        );
        if (options.once) shutdown();
        return;
      }

      if (options.once) {
        publishOnce(envelope);
        return;
      }

      if (!client || !connected) {
        console.warn("[NEXUS:BRIDGE] Broker desconectado; leitura validada, sem publicação");
        return;
      }

      client.publish(topic, JSON.stringify(envelope), { qos: 0, retain: false }, (error) => {
        if (error) {
          console.error("[NEXUS:BRIDGE] Falha ao publicar leitura MQTT");
          return;
        }
        console.info(
          "[NEXUS:BRIDGE] Leitura enviada ao broker MQTT (QoS 0; persistência não confirmada)",
        );
      });
    });

    parser.on("error", () => {
      shutdown("erro ao processar a linha serial");
    });

    serial.on("error", (error) => {
      console.error(`[NEXUS:BRIDGE] Erro na porta serial: ${error.message}`);
      if (!serial.isOpen) {
        reject(error);
      } else {
        shutdown("erro na porta serial; encerrando a bridge");
      }
    });

    serial.open((error) => {
      if (error) {
        reject(new Error(`não foi possível abrir ${options.port}; feche o Monitor Serial e confira a porta COM`));
        return;
      }

      console.info(
        `[NEXUS:BRIDGE] Serial aberta em ${options.port} a ${SERIAL_BAUD_RATE} baud${options.dryRun ? " (dry-run)" : ""}`,
      );

      if (!options.dryRun && !options.once) {
        client = mqtt.connect(brokerUrl, {
          clientId: `nexus-arduino-${process.pid}`,
          clean: true,
          connectTimeout: 15_000,
          keepalive: 30,
          reconnectPeriod: 3_000,
          protocolVersion: 4,
        });

        client.on("connect", () => {
          connected = true;
          console.info("[NEXUS:BRIDGE] Conectada ao broker MQTT");
        });
        client.on("reconnect", () => {
          connected = false;
          console.info("[NEXUS:BRIDGE] Tentando reconectar ao broker MQTT");
        });
        client.on("close", () => {
          connected = false;
          console.info("[NEXUS:BRIDGE] Conexão MQTT encerrada");
        });
        client.on("error", () => {
          connected = false;
          console.error("[NEXUS:BRIDGE] Erro de conexão MQTT; verificando reconexão");
        });
      }
    });
  });
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : "falha inesperada";
  console.error(`[NEXUS:BRIDGE] ${message}`);
  process.exitCode = 1;
});
