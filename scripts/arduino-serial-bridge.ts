import "./load-local-env";

import mqtt, { type MqttClient } from "mqtt";
import { SerialPort } from "serialport";
import { ReadlineParser } from "@serialport/parser-readline";
import { Transform, type TransformCallback } from "node:stream";

import {
  createSignedMqttEnvelope,
  EXPECTED_TOPIC,
  MAX_SERIAL_LINE_BYTES,
  parseArduinoTelemetryLine,
} from "./arduino-serial-protocol";

const SERIAL_BAUD_RATE = 115200;
const DEFAULT_SERIAL_PORT = "COM11";
const DEFAULT_BROKER_URL = "mqtt://broker.emqx.io:1883";

type Options = {
  dryRun: boolean;
  port: string;
  help: boolean;
};

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

function parseOptions(args: string[]): Options {
  let dryRun = false;
  let port = process.env.NEXUS_SERIAL_PORT ?? DEFAULT_SERIAL_PORT;
  let help = false;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--dry-run") {
      dryRun = true;
    } else if (arg === "--port") {
      const next = args[index + 1];
      if (!next || next.startsWith("--")) {
        throw new Error("informe uma porta após --port, por exemplo COM11");
      }
      port = next;
      index += 1;
    } else if (arg === "--help" || arg === "-h") {
      help = true;
    } else {
      throw new Error(`opção desconhecida: ${arg}`);
    }
  }

  if (!port || port.length > 128 || /[\r\n\0]/.test(port)) {
    throw new Error("porta serial inválida");
  }

  return { dryRun, port, help };
}

function printHelp(): void {
  console.info("Uso: npm run arduino:bridge:dry-run -- --port COM11");
  console.info("Para execução autorizada: npm run arduino:bridge -- --port COM11");
  console.info("Feche o Monitor Serial do Arduino IDE antes de iniciar.");
}

function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
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

  const topic = process.env.MQTT_TOPIC ?? EXPECTED_TOPIC;
  if (topic !== EXPECTED_TOPIC) {
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

  lineGuard.on("lineTooLong", () => {
    console.warn("[NEXUS:BRIDGE] Linha serial descartada: excedeu 4096 bytes");
  });

  serial.pipe(lineGuard).pipe(parser);

  return new Promise<void>((resolve, reject) => {
    const closeSerial = () => {
      if (serial.isOpen) {
        serial.close(() => resolve());
      } else {
        resolve();
      }
    };

    const shutdown = () => {
      if (stopping) return;
      stopping = true;
      if (client) {
        client.end(false, {}, closeSerial);
      } else {
        closeSerial();
      }
    };

    process.once("SIGINT", shutdown);
    process.once("SIGTERM", shutdown);

    parser.on("data", (line: string) => {
      let payload;
      try {
        payload = parseArduinoTelemetryLine(line);
      } catch (error) {
        const reason = error instanceof Error ? error.message : "JSON inválido";
        console.warn(`[NEXUS:BRIDGE] Linha descartada: ${reason}`);
        return;
      }

      let envelope;
      try {
        envelope = createSignedMqttEnvelope(payload, token);
      } catch {
        console.error("[NEXUS:BRIDGE] Não foi possível preparar a autenticação MQTT");
        shutdown();
        return;
      }

      if (options.dryRun) {
        console.info(
          `[NEXUS:BRIDGE] Dry-run validado: temperatura ${payload.temperature} °C, ` +
            `umidade ${payload.humidity}%, presença ${payload.presence ? "sim" : "não"}, ` +
            `luminosidade raw ${payload.light}; MQTT desativado.`,
        );
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
        console.info("[NEXUS:BRIDGE] Leitura publicada para o NEXUS");
      });
    });

    parser.on("error", () => {
      console.error("[NEXUS:BRIDGE] Erro ao processar a linha serial");
      shutdown();
    });

    serial.on("error", (error) => {
      console.error(`[NEXUS:BRIDGE] Erro na porta serial: ${error.message}`);
      if (!serial.isOpen) {
        reject(error);
      } else {
        shutdown();
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

      if (!options.dryRun) {
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
