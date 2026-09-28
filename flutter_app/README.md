# NEXUS Flutter App

Flutter client for NEXUS human authentication and hotel/device/readings views. All Supabase table reads use the signed-in user's session and existing RLS policies.

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

The app uses Supabase Auth's persisted session. The dashboard and data pages query Supabase directly as the authenticated user; the Flutter app does not connect to MQTT.
