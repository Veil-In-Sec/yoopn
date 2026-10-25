import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  /// Logging is a debug aid (telemetry reports errors on its own); release
  /// builds short-circuit every call before any string is built.
  static bool enabled = kDebugMode;

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

    developer.log(
      message,
      time: now,
      name: tag,
      error: error,
      stackTrace: stackTrace,
      level: _levelValue(level),
    );

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

  static String short(Object? value, [int? max]) {
    final s = '$value';
    final m = max ?? maxLength;
    if (s.length <= m) return s;
    return '${s.substring(0, m)}…(${s.length} chars)';
  }

  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].length < 2) return '***@***';
    final name = parts[0];
    final head = name.substring(0, name.length >= 3 ? 3 : 1);
    return '$head***@${parts[1]}';
  }
}
