# YooPN — Real VPN Setup

Real OpenVPN tunneling via `openvpn_flutter: ^1.3.4` + VPNGate configs
(credentials `vpn` / `vpn`). `flutter analyze` clean.

## What was changed

- `pubspec.yaml`: added `openvpn_flutter`.
- `lib/features/dashboard/data/tunnel/openvpn_tunnel.dart` (new):
  `OpenVpnTunnel implements VpnTunnel` — initialize, `filteredConfig`,
  `requestPermissionAndroid`, 30s connect timeout, `VPNStage → VpnTunnelStatus`
  mapping, full `TUNNEL` logging.
- `lib/core/utils/dependency_injection.dart`: Android/iOS → `OpenVpnTunnel`,
  web/desktop → `SimulatedVpnTunnel` (tests keep working).
- `android/.../MainActivity.kt`: forwards VPN-consent result via
  `OpenVPNFlutterPlugin.connectWhileGranted(...)` (else connect hangs).
- `AndroidManifest.xml`: `android:extractNativeLibs="true"`.
- `android/gradle.properties`: `android.bundle.enableUncompressedNativeLibs=false`.
- `android/app/build.gradle.kts`: `packaging.jniLibs.useLegacyPackaging=true`.
- `ios/VPNExtension/PacketTunnelProvider.swift` + `README.md`: template +
  manual Xcode steps.
- `lib/features/dashboard/data/tunnel/vpn_tunnel.dart`: doc updated.

## Stuck on "Connecting…"? (fixed)

The tunnel now: 15s timeout on the `engine.connect` call itself, 2s grace
period for the engine's initial `disconnected` reset emission, a 3s
`stage()` polling fallback for missed callbacks, and a cancel path (power
button / Cancel button) that aborts the in-flight attempt. The status panel
shows the live sub-stage (`Authenticating…`, `Assigning IP…`), elapsed
seconds, and a Cancel button. Timeouts name the stage they died at
(`Stuck at "assign_ip" — try another server`).

## Production telemetry

Supabase-backed analytics + crash reports — see `supabase/README.md`.
Quick check: `./supabase/probe.sh` (both inserts must print HTTP 201).

## Notification permission (Android 13+)

`lib/core/utils/notification_permission.dart` requests `POST_NOTIFICATIONS`
in `YooPNApp.initState` (first frame, never blocking startup) because the
plugin's `de.blinkt.openvpn.core.OpenVPNService` runs
`foregroundServiceType="systemExempted"` and can stall its handshake when the
persistent notification is suppressed. Denial does not block the tunnel; it is
logged under `PERM`. iOS needs nothing (NetworkExtension raises its own
consent sheet).

## Android — ready to test

```bash
flutter pub get
flutter run -d <android-device>
```

Tap a **live VPNGate relay** (flag + host/IP shown), then power button.
Expect: notification permission prompt on first launch → system VPN-consent
dialog → `TUNNEL engine stage=... → connected`, system VPN key icon, IP
changes. Static fallback servers (US/UK/DE/SG with no host) correctly refuse
with `bad-config` — pick a live relay instead. Denying VPN permission yields
`permission-denied`; slow servers yield `timeout` after 30s.

> Build note: do **not** add `android.bundle.enableUncompressedNativeLibs` to
> `gradle.properties`. AGP 9.x removed it (deprecated in 8.1) and the build
> fails; `packaging.jniLibs.useLegacyPackaging` in `app/build.gradle.kts` is
> the supported equivalent.

## iOS — one manual step left

Follow `ios/VPNExtension/README.md` (create Network Extension target, App
Group `group.com.vis.yoopn.vpn`, extension id `com.vis.yoopn.VPNExtension`,
pod `OpenVPNAdapter:0.8.0`). Must match `OpenVpnTunnel.iosGroupId` /
`iosProviderBundleId`. Test on a real device.

## Notes

- `openvpn_flutter` is GPL-3.0 (like `OpenVPNAdapter`/`ics-openvpn`) —
  distributing the app has GPL obligations. Alternative (`axevpn_flutter`)
  is also GPL.
- Android 13+: the plugin posts a persistent notification; grant
  `POST_NOTIFICATIONS` when prompted (already in manifest).
- VPNGate relays are volunteer-run; if one fails, the UI shows the mapped
  `VpnFailure` and logs the raw stage under `TUNNEL`.
