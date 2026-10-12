# YooPN — Project Context

> Single source of truth for agents/sessions. Update it when architecture,
> dependencies, or scope decisions change. Last verified: 12-Oct-2026
> (`flutter analyze` clean, `flutter test` 50/50 — post race/spacing/arch
> audit: fetch slots serialized, tunnel reentrancy guards, ad-gate join
> semantics, `Spacing.*` for all gaps, `showAppSnackBar`, `server_ranking`
> single sort/filter, `initDependencyInjection` idempotent).

## 1. Overview

- **What:** YooPN (`yoopn`, v1.0.0+1, `com.vis.yoopn`) — Flutter VPN client.
  Supabase auth, VPNGate public relays, **real OpenVPN tunneling** via
  `openvpn_flutter ^1.3.4` (creds `vpn`/`vpn`), Supabase-backed telemetry.
- **Target:** Android-first and working. iOS deferred — extension code is a
  template, one manual Xcode step remains (`ios/VPNExtension/README.md`).
- **Deep link:** `io.supabase.yoopn://login-callback` (Android + iOS).
- **Status:** Tunnel real on Android/iOS, simulated on web/desktop.
  Release signing skipped (debug keys).

## 2. Stack

- Flutter 3.47.6 / Dart 3.13.5. Design 375x812 (`flutter_screenutil`).
- `flutter_bloc ^9.1.1`, `go_router ^18.0.2`, `get_it ^9.3.0`,
  `supabase_flutter ^2.8.4`, `dio ^5.11.1`, `connectivity_plus`,
  `openvpn_flutter ^1.3.4` (**GPL-3.0** — distribution has obligations),
  `permission_handler ^12.0.0`, `lottie`, `flutter_dotenv`.
  (Dead deps removed 12-Oct-2026: `cupertino_icons`, `flutter_svg` —
  zero imports anywhere. `google_fonts` was never a dependency.)
- `sqflite 2.4.4+1` + `path` + `sqflite_common_ffi` (desktop tests).
  Deliberately **sqflite, not shared_preferences**.
- Theme: orange `#F25C00`, Inter **bundled** (`assets/fonts/`, 18pt only).
- `.env` is bundled for LOCAL DEV ONLY (key ships in APK); release uses
  `--dart-define` (`pubspec.yaml:75-81`). `.env` is configured — don't ask.

## 3. Entry & Wiring

- `lib/main.dart` — zone-guarded boot: `AppBlocObserver`, crash handlers with
  benign-error filter (overflows, transient network excluded), Supabase init,
  DI, portrait lock, edge-to-edge.
- `lib/app.dart` — `YooPNApp` (stateful): provides Splash/Auth/Vpn blocs,
  `MaterialApp.router`, post-frame `POST_NOTIFICATIONS` request (OpenVPN
  foreground service stalls without it; denial is non-blocking).
- `lib/core/utils/dependency_injection.dart` — GetIt. `VpnTunnel`:
  Android/iOS → `OpenVpnTunnel`, web/desktop → `SimulatedVpnTunnel`.
  `VpnLocalDataSource`: sqflite on Android/iOS/macOS, in-memory on
  web/Windows/Linux.
- Routes `lib/core/routes/` — `/` splash, `/home`, `/auth`, `/password`,
  `/profile`, `/menu`, `/terms`, `/safety`, `/disclaimer`.
  `app_routes.dart` has auth-guard redirect + `TelemetryNavigatorObserver`.

## 4. Features

### auth/ (password w/ auto-signup fallback, OTP, Google OAuth, profile edits)

- Remote datasource + repository + `AuthUserEntity(id/email/photoUrl/
  displayName)`; 9 usecases incl. `update_display_name/email/password`.
- `auth_bloc.dart` (session stream, validation, telemetry) +
  `helper/friendly_auth_error.dart` (one-line snackbars, never raw errors).
- Views: carousel `auth_screen.dart`, `password_screen.dart`; profile edits
  live in dashboard's `profile_screen.dart` via `helper/sign_out_action.dart`
  (confirm → disconnect tunnel → sign out → `go(auth)`).

### dashboard/ (home, menu, info docs, profile, promo)

- **VPNGate pipeline — CSV → JSON → models** (owner-mandated shape):
  `data/models/vpn_server_model.dart` (`csvToJson`, tolerant Message commas,
  skips `*`/`#`; `fromJson`/`serversFromJson`, score DESC).
  `VpnServer` entity: `hostName` = stable id, `isVpnGate`, `toJson()`,
  `decodedOpenVpnConfig`, `matchesId`, flag/speed/ping helpers.
  `availableServers` (4 static, config-less) = placeholder only — correctly
  refused with `bad-config`.
- **Server sourcing (priority order):** bundled `assets/servers_snapshot.json`
  (98 relays, regen via `tool/fetch_snapshot.dart`) → memory → sqflite
  (`servers` table hostName PK + `meta`, `loadBestServer` = score DESC /
  ping ASC) → live `https://www.vpngate.net/api/iphone/` (5 attempts, isolate
  parse, 15-min TTL) → merge + background persist.
- **Tunnel:** `data/tunnel/openvpn_tunnel.dart` — init once (memoized),
  reentrancy-guarded connect, Android permission, per-route timeouts (30s
  total, 8s min), TCP-first remote variants, `VPNStage → VpnTunnelStatus` +
  human text (`Authenticating…`, `Assigning IP…`), 3s poll fallback with
  generation guard, 2s early-disconnect grace, cancel path, `TUNNEL` logs.
  `vpn_tunnel.dart` holds the interface + cancellable simulator.
- **Ads (AdMob):** `google_mobile_ads ^9.1.0`, `core/ads/AdConfig`
  (Google test ids in debug; production ids via
  `--dart-define=ADMOB_APP_ID/ADMOB_BANNER_ID`), `core/ads/
  BannerAdWidget` (320x50, reserved-height placeholder + graceful fallback),
  initialized in `main.dart` (never blocks startup). Manifest + Info.plist
  carry the TEST App ID — replace with yours for release. Home header runs
  a dotless ad carousel above YooPN+; promo sheet has 2 carousel slots.
- **Ad gates (rewarded VIDEO):** `core/ads/` — `RewardedAdManager`
  (preloaded at startup, auto-reloads; test id in debug, `ADMOB_REWARDED_ID`
  dart-define for release), `ad_gate.dart` (non-dismissible 30s countdown,
  action always proceeds after), `server_change_gate.dart` + `ad_counter_store`
  (sqflite-persisted: first 8 server changes free, gated from the 9th).
  Every connect/disconnect runs the 30s gate; mid-handshake cancel stays
  immediate.
- **Bloc** `presentation/bloc/vpn_bloc.dart` — 7 events
  (`Toggled/ServerSelected/ServersRequested/DetailChanged/TunnelSync/
  BackgroundRefreshed/Failed`); single-flight + 2s refresh budget; auto
  best-relay w/ manual-pick preservation; `connectedSince` timer;
  `connectionDetail` live sub-stage; telemetry on every outcome.
- **UI:** `dashboard_screen.dart` (`Stack(Home, PromoSheet)`, auto-fetch +
  tunnel-sync on entry); `home_screen.dart` (1.1.1.1-style: header + FREE +
  neon `connect_button.dart` + `status_panel.dart` with HH:MM:SS + Cancel);
  `menu_screen.dart` (servers entry w/ live count, account, docs, logout,
  by VIS Softs); `servers_screen.dart` (full-page list: search, refresh,
  tap-to-select while disconnected); `info_screen.dart`
  (terms/safety/disclaimer consts); `profile_screen.dart`
  (OAuth avatar, tiles, edit dialogs); `promo_sheet.dart`
  (servers entry + always-on ad slots; AdMob banner swap pending).
  **Removed:** speed-test screen/cubit/datasource, server bottom-sheet,
  bottom nav, and the premium/subscription stack (owner: ads only, no
  premium) — do not re-add without owner sign-off.

### splash/

- 300ms logo + `LottieWarmup` (background-isolate parse) + session check w/
  retry; prefetch gate: waits for servers `loaded/failure` or 6s before
  routing; handles OAuth deep-link race.

### Cross-cutting (`lib/core/`)

- `telemetry/supabase_telemetry.dart` (`track/screen/reportCrash` → Postgres,
  never-throws, masked PII) + `telemetry_navigator_observer.dart`.
- `utils/app_logger.dart` (tagged `TUNNEL/VPN/GATE/TELEMETRY/PERM…`),
  `app_bloc_observer.dart`, `dio_logger_interceptor.dart` (truncated bodies),
  `notification_permission.dart`, `lottie_warmup.dart`,
  `errors/vpn_failures.dart` (`VpnException` codes → `VpnFailure` messages).

## 5. Native & Backend Ops

- **Android (wired):** `MainActivity.kt` forwards VPN-consent
  (`connectWhileGranted`, else connect hangs); manifest has
  `BIND_VPN_SERVICE`, FGS, `POST_NOTIFICATIONS`, `extractNativeLibs=true`;
  `useLegacyPackaging=true` (do NOT add `enableUncompressedNativeLibs` —
  AGP 9 removed it). Release keystore opt-in via `android/key.properties`.
- **iOS (manual):** create Network Extension target `VPNExtension`
  (`com.vis.yoopn.VPNExtension`), App Group `group.com.vis.yoopn.vpn`,
  pod `OpenVPNAdapter:0.8.0`, test on real device. Must match
  `OpenVpnTunnel.iosGroupId/iosProviderBundleId`.
- **Telemetry backend:** `supabase/` — run `migrations/001_app_telemetry.sql`
  in SQL editor, verify with `./supabase/probe.sh` (both HTTP 201); on RLS
  42501 also run `002_fix_telemetry_rls.sql`. Details in `supabase/README.md`;
  Android test flow in `VPN_SETUP.md`.

## 6. Decisions Log (binding)

1. sqflite over shared_preferences for server cache.
2. Android-first; iOS later.
3. Foreground notification: "YooPN" / "Protecting your connection".
4. Release signing/store skipped for now.
5. `.env` configured — don't request Supabase keys again.
6. Speed-test + server-picker + bottom-nav dropped (commit `8bbff91`) —
   re-adding needs owner sign-off.
7. No premium tier — ads only (owner call 12-Oct-2026). Subscription stack
   removed; promo ad slots always visible; server selection lives on the
   `/servers` page. Real AdMob needs owner's App ID + ad unit IDs.

## 7. Run / Verify

```bash
flutter pub get
flutter analyze --no-pub     # must be clean
flutter test                 # 50 tests (bloc, tunnel, entity, csv→json, cache, telemetry, ads)
flutter run -d <android-id>  # tap a LIVE relay (flag+host/IP), then power button
dart run tool/fetch_snapshot.dart  # refresh bundled server snapshot
```

First connect shows a system VPN-consent dialog a human must accept.
Static US/UK/DE/SG entries intentionally fail with `bad-config`.
