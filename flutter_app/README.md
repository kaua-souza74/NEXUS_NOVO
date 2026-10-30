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

The design prototype's extra spaces and devices remain local demonstration data. Device `ESP32-001` is shown as `001` and represents the UNO R4 WiFi. Its readings arrive through `nexus/vista-real/quarto-101/ESP32-001/readings` (single publication) or `nexus/vista-real/piscina/ESP32-001/readings` (continuous bridge), are ingested by the MQTT consumer into Supabase, and appear in the app through the authenticated dashboard repository. The app determines online status from the device's `last_seen_at` in Supabase, with a two-minute freshness window; a successful bridge publish alone does not update that status. The legacy `ESP32-00` and database spaces marked as tests are hidden from the app, without deleting database records.
