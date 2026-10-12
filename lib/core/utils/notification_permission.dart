import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yoopn/core/utils/app_logger.dart';

class NotificationPermission {
  NotificationPermission._();

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