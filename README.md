# YooPN

Flutter VPN client. Live relay list from VPNGate, real OpenVPN tunneling on
Android/iOS, Supabase auth, and Supabase-backed production telemetry.

## Stack

| Concern | Choice |
|---|---|
| SDK | Flutter `3.47.6` (FVM), Dart `^3.13.5` |
| State | `flutter_bloc` + `equatable` |
| DI | `get_it` (`sl` service locator) |
| Routing | `go_router` + Supabase-session redirect guard |
| Backend | `supabase_flutter` (auth/session) |
| Network | `dio` (VPNGate CSV, speed test) |
| Tunnel | `openvpn_flutter` (real) / simulated on desktop |
| Local | `sqflite` (mobile) vs in-memory (desktop/web) |
| Logging | `app_logger.dart` + Bloc observer + Dio interceptor |
| Telemetry | `supabase_telemetry.dart` → Postgres tables |

## Layout

```
lib/
  main.dart                     bootstrap, crash handlers, notification prompt
  app.dart                      global blocs + MaterialApp.router
  core/
    config/supabase_config.dart   dart-define → .env fallback
    errors/vpn_failures.dart      VpnException → user-facing VpnFailure
    routes/                       go_router + auth guard
    telemetry/                    Supabase analytics + crash reports
    themes/ utils/ resources/     design system, helpers, asset paths
  features/
    auth/       email+password (auto sign-up), Google OAuth, email OTP
    dashboard/  home + speed test + profile tabs, VPN server list
    splash/     session gate
```

## Run

```sh
flutter pub get
flutter run -d <device>
```

Development reads config from `.env` (copy `.env.example`). Sign in, pick a
**live VPNGate relay** (the built-in US/UK/DE/SG entries have no OpenVPN
config and refuse to connect), tap the power button, allow the system VPN
prompt.

## Build release

`.env` is bundled as an asset for development. For release, pass config via
`--dart-define` so the Supabase key is not embedded in the APK:

```sh
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx \
  --dart-define=REDIRECT_URL=io.supabase.yoopn://login-callback
```

Then remove the `- .env` line from `pubspec.yaml`. Release signing needs
`android/key.properties` (see `android/app/build.gradle.kts`); without it the
release build falls back to debug keys and logs a warning.

## Verify

```sh
flutter analyze          # must be clean
flutter test             # 50 tests
./supabase/probe.sh      # telemetry inserts return HTTP 201
```

## Docs

* `VPN_SETUP.md` — OpenVPN tunnel setup, Android/iOS specifics, troubleshooting
* `supabase/README.md` — telemetry tables, review queries, privacy

## Notes

* iOS tunneling requires the Network Extension target described in
  `ios/VPNExtension/README.md` (Xcode-only, cannot be scripted).
* `openvpn_flutter`, `ics-openvpn` and `OpenVPNAdapter` are GPL-3.0 —
  distributing YooPN carries GPL obligations.
* VPNGate relays are volunteer-run; individual relays fail often.