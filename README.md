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
