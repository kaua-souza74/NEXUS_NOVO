export type BridgeOptions = {
  dryRun: boolean;
  once: boolean;
  port: string;
  help: boolean;
};

export function parseBridgeOptions(
  args: string[],
  configuredPort = process.env.NEXUS_SERIAL_PORT ?? "COM11",
): BridgeOptions {
  let dryRun = false;
  let once = false;
  let port = configuredPort;
  let help = false;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--dry-run") {
      dryRun = true;
    } else if (arg === "--once") {
      once = true;
    } else if (arg === "--port") {
      const next = args[index + 1];
      if (!next || next.startsWith("--")) {
        throw new Error("informe uma porta após --port, por exemplo COM12");
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

  return { dryRun, once, port, help };
}
