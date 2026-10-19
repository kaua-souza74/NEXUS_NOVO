# NEXUS Flutter App

Flutter client for NEXUS human authentication and hotel/device/readings views. The visual system and responsive pages are integrated from the separate `nexus_design` prototype. All database reads use the signed-in user's Supabase session and existing RLS policies.

## Supabase configuration

The public project URL and Supabase publishable key are set as safe client
defaults in `lib/config.dart`, so a fresh clone can run without a machine-local
configuration file. Publishable keys are designed for client apps; database
access must remain protected by Supabase Auth and Row Level Security (RLS).
Never add `SUPABASE_SECRET_KEY`, `service_role`, or device credentials to this
Flutter app or to Git.

You can override the defaults for a local build with `--dart-define` if needed.

## Run

```powershell
cd flutter_app
flutter pub get
flutter run -d chrome
```

In VS Code, open the repository root and press **F5** with **NEXUS Flutter
(Chrome)** selected in Run and Debug. The checked-in launcher runs `flutter pub
get` from this app folder before starting Chrome.

The app uses Supabase Auth's persisted session. The dashboard reads the hotel, membership, spaces, devices and sensor readings through the authenticated Flutter client. It never uses the server secret key.

The design prototype's extra spaces and devices remain clearly labeled as local demonstration data. `ESP32-001` can display its stored Wokwi readings when RLS permits. `ESP32-00` is reserved for the physical Arduino and opens a manual bench-test checklist. That checklist is temporary UI state: it does not publish MQTT messages or write to Supabase. Physical ingestion should be enabled only after the ESP32-00 record and device credentials are provisioned.
