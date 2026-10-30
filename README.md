# NEXUS

This repository contains the NEXUS web app, the Flutter client, and ESP32
firmware. The Flutter project is in `flutter_app/`.

## Run the Flutter app

Install Flutter with Dart 3.10.8 or newer, install the Flutter extension in
VS Code, then open this repository folder. Press **F5** and select
**NEXUS Flutter (Chrome)**. The VS Code launch task resolves dependencies and
starts the app in Chrome.

From a terminal instead:

```powershell
cd flutter_app
flutter run -d chrome
```

`flutter_app/pubspec.lock` is tracked so other machines use the same resolved
package versions. The app uses its public Supabase URL and publishable key from
`flutter_app/lib/config.dart`. Supabase secret/service-role keys and local
device credentials stay in ignored local files and must never be committed.

See [`flutter_app/README.md`](flutter_app/README.md) for app and data details.

## Arduino UNO R4 WiFi (USB Serial → MQTT → Supabase)

The UNO R4 firmware is in `firmware/arduino_uno_r4_nexus/`. It sends one JSON
object per line over USB Serial at 115200 baud. The Node bridge in
`scripts/arduino-serial-bridge.ts` validates the line, signs it with the local
device token through the shared MQTT authentication helper, and targets the
`ESP32-001` MQTT topic. The one-shot path uses the requested `quarto-101` topic;
the consumer also accepts the current Piscina topic. The consumer calls the transactional
`ingest_device_readings` RPC; that function writes temperature, humidity,
presence, light (`raw`), and door readings and updates `last_seen_at` together.

Install the locked Node dependencies once with `npm ci`. Install the Adafruit
DHT sensor library and Adafruit Unified Sensor in Arduino IDE, then follow the
pinout and upload steps in
[`firmware/arduino_uno_r4_nexus/README.md`](firmware/arduino_uno_r4_nexus/README.md).
Set `NEXUS_DEVICE_TOKEN_ESP32_001` in the ignored local `.env.local` file; never
commit or print its value.

With the firmware uploaded, the board connected as COM11, and Arduino IDE's
Serial Monitor closed, validate serial parsing and signing without connecting
to MQTT or writing to Supabase:

```powershell
npm run test:iot
npm run arduino:bridge:dry-run -- --port COM11
```

After explicit authorization, publish exactly one reading from COM12 with:

```powershell
npm run arduino:bridge -- --port COM12 --once
```

The bridge waits for the MQTT QoS 1 callback and does not retry a failed
publication. Do not run this command before authorization.
