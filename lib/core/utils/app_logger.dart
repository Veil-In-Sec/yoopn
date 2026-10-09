import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Central tagged logger for the whole app.
///
/// Usage:
/// ```dart
/// AppLogger.d('AUTH', 'signIn attempt for $email');
/// AppLogger.i('VPN', 'connected to $serverId');
/// AppLogger.w('NET', 'offline, serving cache');
/// AppLogger.e('VPN', 'connect failed', error, stackTrace);
/// ```
///
/// - In debug: prints to console with emoji + timestamp + tag.
/// - Always: forwards to `dart:developer log` so DevTools Logging view works.
/// - Never log passwords, OTP codes, tokens or full OpenVPN configs.
///   Log lengths / masked values instead (see [maskEmail]).
class AppLogger {
  AppLogger._();

  /// Master switch. Keep `true` while developing.
  static bool enabled = true;

  /// Max chars for inline values (prevents 10MB CSV dumps in logs).
  static int maxLength = 400;

  static void d(String tag, String message) =>
      _log(level: 'DEBUG', emoji: '🐛', tag: tag, message: message);

  static void i(String tag, String message) =>
      _log(level: 'INFO', emoji: '💡', tag: tag, message: message);

  static void w(String tag, String message, [Object? error]) =>
      _log(level: 'WARN', emoji: '⚠️', tag: tag, message: message, error: error);

  static void e(String tag, String message,
      [Object? error, StackTrace? stackTrace]) =>
      _log(
        level: 'ERROR',
        emoji: '❌',
        tag: tag,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );

  static void _log({
    required String level,
    required String emoji,
    required String tag,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final buffer = StringBuffer('$emoji [$time][$level][$tag] $message');
    if (error != null) buffer.write(' | err=$error');

    // DevTools Logging view (works in debug + profile).
    developer.log(
      message,
      time: now,
      name: tag,
      error: error,
      stackTrace: stackTrace,
      level: _levelValue(level),
    );

    // Console output (debug only to keep release APK clean).
    if (kDebugMode) {
      debugPrint(buffer.toString());
      if (stackTrace != null) {
        final lines = stackTrace.toString().split('\n').take(6).join('\n');
        debugPrint('   ↳ $lines');
      }
    }
  }

  static int _levelValue(String level) {
    switch (level) {
      case 'DEBUG':
        return 500;
      case 'INFO':
        return 800;
      case 'WARN':
        return 900;
      case 'ERROR':
        return 1000;
      default:
        return 0;
    }
  }

  /// Truncate long values (CSV bodies, JSON, configs) before logging.
  static String short(Object? value, [int? max]) {
    final s = '$value';
    final m = max ?? maxLength;
    if (s.length <= m) return s;
    return '${s.substring(0, m)}…(${s.length} chars)';
  }

  /// `john.doe@mail.com` -> `joh***@mail.com`. Safe to log.
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].length < 2) return '***@***';
    final name = parts[0];
    final head = name.substring(0, name.length >= 3 ? 3 : 1);
    return '$head***@${parts[1]}';
  }
}
