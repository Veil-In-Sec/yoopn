# iOS VPN Extension — one-time manual setup (Xcode on a Mac)

Dart side is ready (`OpenVpnTunnel.iosGroupId/iosProviderBundleId`).
Apple requires the Packet Tunnel target to exist in the Xcode project —
it cannot be created from the command line.

## Steps

1. Open `ios/Runner.xcworkspace` in Xcode.
2. File → New → Target → **Network Extension** → name `VPNExtension`.
   - Bundle ID must be exactly `com.vis.yoopn.VPNExtension`.
3. Runner target + VPNExtension target → Signing & Capabilities → **+ App Groups**
   → `group.com.vis.yoopn.vpn` (both targets, same group).
4. Both targets → **+ Network Extensions** → check **Packet Tunnel**.
5. Replace the generated `PacketTunnelProvider.swift` in the VPNExtension
   target with `ios/VPNExtension/PacketTunnelProvider.swift` from this repo.
6. VPNExtension `Info.plist` must contain:
   ```xml
   <key>NSExtension</key>
   <dict>
     <key>NSExtensionPointIdentifier</key>
     <string>com.apple.networkextension.packet-tunnel</string>
     <key>NSExtensionPrincipalClass</key>
     <string>$(PRODUCT_MODULE_NAME).PacketTunnelProvider</string>
   </dict>
   ```
7. Add to `ios/Podfile` (create it via `flutter build ios` first if missing):
   ```ruby
   target 'VPNExtension' do
     use_frameworks!
     pod 'OpenVPNAdapter', :git => 'https://github.com/ss-abramchuk/OpenVPNAdapter.git', :tag => '0.8.0'
   end
   ```
8. `pod install`, run on a **real device** (simulator cannot do VPN).
9. Apple review: see https://developer.apple.com/app-store/review/guidelines/#vpn-apps.
   The plugin uses exempt encryption.

If bundle IDs / group mismatch `OpenVpnTunnel` init, iOS connect will fail
with a clear log in the `TUNNEL` tag.
