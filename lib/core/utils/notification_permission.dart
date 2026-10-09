import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Runtime permission for the Android foreground-service notification that
/// `openvpn_flutter` posts while a tunnel is up.
///
/// Why it matters: `de.blinkt.openvpn.core.OpenVPNService` runs with
/// `foregroundServiceType="systemExempted"` (API 34+). On Android 13+ a
/// denied `POST_NOTIFICATIONS` suppresses that notification, and the engine
/// can stall waiting for it — the UI then hangs on "Connecting…".
///
/// iOS needs no equivalent: the system VPN consent sheet is raised by
/// NetworkExtension, and `VPNGate` relays need no local-network permission
/// for the tunnel itself.
class NotificationPermission {
  NotificationPermission._();

  /// Ask once per app launch, before the user can hit connect.
  ///
  /// Failures are logged and swallowed — notifications are a UX nicety and
  /// must never block startup or block the VPN.
  static Future<bool> ensureGranted() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      AppLogger.d('PERM', 'notifications: not Android, skipping');
      return true;
    }
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) {
        AppLogger.d('PERM', 'notifications already granted');
        return true;
      }
      if (status.isPermanentlyDenied) {
        // Re-prompting is a no-op once permanently denied; direct the user to
        // settings instead of silently failing.
        AppLogger.w(
          'PERM',
          'notifications permanently denied — user must enable in Settings',
        );
        return false;
      }

      final result = await Permission.notification.request();
      AppLogger.i('PERM', 'notifications request → $result');
      if (!result.isGranted) {
        AppLogger.w(
          'PERM',
          'notifications denied — VPN may still connect, but the '
          'foreground-service notification stays hidden',
        );
      }
      return result.isGranted;
    } catch (e, st) {
      AppLogger.e('PERM', 'notification permission failed', e, st);
      return false;
    }
  }

  /// True when the user has blocked the prompt permanently.
  static Future<bool> isPermanentlyDenied() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return (await Permission.notification.status).isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }
}