# Kutsu Companion (Flutter) — v0.9

Android companion app for the **Kutsu Sense** environmental air-quality monitor
(CO₂, VOC index, NOx index, temperature, humidity, optional combustible-gas/smoke).
It talks to the device over Bluetooth LE using the shared **Kutsu GATT contract**
(see [`PROVISIONING.md`](PROVISIONING.md) and [`lib/ble/contract.dart`](lib/ble/contract.dart)),
the same contract the firmware exposes.

Stack: `flutter_blue_plus` (BLE) · `provider` (state) · `sqflite` (local storage) ·
`flutter_map` + OpenStreetMap / Esri / OpenTopoMap tiles (key-free) ·
`fl_chart` (graphs) · `geolocator` + `geocoding` · `firebase` (optional community map).

## Features

- **Device** — scan, connect, bind for **auto-reconnect**, live status.
- **Live** — real-time readings with sparkline graphs and severity coloring.
- **Map** — your located readings as heatmap / cluster previews / individual
  floating readings (by zoom), **metric filters** that drive the coloring,
  **base-map styles** (Standard / Satellite / Dark / Terrain), **custom markers**,
  a recenter button, date/run filtering, and a **Global** tab backed by an
  anonymous community database.
- **Stats** — an interactive trend chart (scroll + pinch-zoom, time axis,
  auto-refresh), CSV export, and a device debug log. Trends can be shown per
  **Session** or per **Location** (radius + period around a point you pick on the map).
- **Settings** — device name/mode/outputs, alert thresholds, **sensor refresh
  rate**, **Trends** preferences, WiFi provisioning, community contribution, and
  **import readings from the device's SD card over BLE**.

## Requirements

- **Flutter SDK 3.4+** (`flutter --version`) and the Android SDK (compileSdk 36, minSdk 23).
- A **physical Android phone** — BLE does not work in the emulator.

## Firebase setup (required to build)

The optional community map uses Firebase (anonymous Auth + Cloud Firestore). The
project's Firebase keys are **not** committed, so you generate your own:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

This writes `lib/firebase_options.dart` and `android/app/google-services.json`
(both git-ignored). See [`lib/firebase_options.dart.example`](lib/firebase_options.dart.example)
for the shape. In the Firebase console enable **Anonymous Authentication** and
create a **Cloud Firestore** database, then set security rules for the
`observations` collection (public read, authenticated append-only — see the
rules snippet in `PROVISIONING.md`). Consider enabling **App Check** and a budget
alert for a public deployment.

> The app degrades gracefully if Firebase init fails — only the community
> **Global** tab and **Contribute** action need it.

## Build & run

```bash
flutter pub get
flutter run        # builds + installs on a connected phone (USB debugging on)
```

To build a release APK:

```bash
flutter build apk --release
```

> `applicationId` / `iosBundleId` default to `com.example.…`. If you fork this,
> change them (and re-run `flutterfire configure`) to your own identifiers.

## Architecture

```
main.dart → ChangeNotifierProvider(KutsuState) → SplashScreen → RootNav
  ble/contract.dart        UUIDs + metric/threshold maps (the GATT contract)
  ble/kutsu_ble.dart       flutter_blue_plus client (scan/connect/read/write/notify, SD dump)
  state/kutsu_state.dart   ChangeNotifier owning connection, tracking, autoconnect, trends
  state/trends.dart        Trends (session/location) config model
  store/db.dart            sqflite: records, markers, kv prefs, geo/run/session queries
  services/community_service.dart  Firestore upload + Global fetch (anonymous)
  screens/*                one file per screen + map/stat custom layers
```

## Notes

- **Map tiles** are key-free sources for development; respect each provider's tile
  usage policy (OpenStreetMap, Esri, OpenTopoMap) for production and set an
  appropriate `userAgentPackageName`.
- **Permissions** (Bluetooth + location) are requested at runtime on first scan.
- Local readings are stored on-device in SQLite; nothing leaves the phone unless
  you explicitly **Contribute** to the community map (anonymous, no device id).

## License

Apache License 2.0 — see [`LICENSE`](LICENSE).
