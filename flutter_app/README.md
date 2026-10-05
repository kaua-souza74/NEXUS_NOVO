# NEXUS Flutter App

Flutter client for NEXUS human authentication and hotel/device/readings views. The visual system and responsive pages are integrated from the separate `nexus_design` prototype. All database reads use the signed-in user's Supabase session and existing RLS policies.

## Local configuration

Create `supabase.local.json` in this directory with only public client settings:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

This local file is ignored by Git. Never add `SUPABASE_SECRET_KEY`, `service_role`, or device credentials to this Flutter app.

## Run

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=supabase.local.json
```

The app uses Supabase Auth's persisted session. The dashboard reads the hotel, membership, spaces, devices and sensor readings through the authenticated Flutter client. It never uses the server secret key.

The design prototype's extra spaces and devices remain clearly labeled as local demonstration data. `ESP32-001` can display its stored Wokwi readings when RLS permits. `ESP32-00` is reserved for the physical Arduino and opens a manual bench-test checklist. That checklist is temporary UI state: it does not publish MQTT messages or write to Supabase. Physical ingestion should be enabled only after the ESP32-00 record and device credentials are provisioned.
