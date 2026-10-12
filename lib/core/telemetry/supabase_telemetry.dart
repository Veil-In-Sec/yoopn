import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/core/utils/app_logger.dart';

class Telemetry {
  Telemetry._();

  static bool enabled = true;

  static String appVersion = '1.0.0+1';

  static String? _sessionId;

  static String get sessionId {
    return _sessionId ??= '${DateTime.now().millisecondsSinceEpoch}-'
        '${Random().nextInt(1 << 32).toRadixString(16)}';
  }

  static void init() {
    _sessionId = null;
    AppLogger.i('TELEMETRY', 'session $sessionId (app $appVersion)');
    track('app_open', {
      'platform': defaultTargetPlatform.name,
      'debug': kDebugMode,
    });
  }

  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _base() => {
    'session_id': sessionId,
    'platform': defaultTargetPlatform.name,
    'app_version': appVersion,
    'user_id': _client?.auth.currentUser?.id,
  };

  static Future<void> track(
    String event, [
    Map<String, Object?> props = const {},
  ]) async {
    if (!enabled) return;
    final client = _client;
    if (client == null) {
      AppLogger.d('TELEMETRY', 'skip $event (supabase not ready)');
      return;
    }
    AppLogger.d('TELEMETRY', 'track $event $props');
    try {
      await client.from('analytics_events').insert({
        ..._base(),
        'event': event,
        'props': props,
      });
    } catch (e) {
      AppLogger.w('TELEMETRY', 'track $event dropped: $e');
    }
  }

  static Future<void> screen(String name) =>
      track('screen_view', {'screen': name});

  static Future<void> reportCrash(
    Object error,
    StackTrace? stackTrace, {
    Map<String, Object?> context = const {},
    bool fatal = true,
  }) async {
    AppLogger.e('TELEMETRY', 'crash: $error', error, stackTrace);
    if (!enabled) return;
    final client = _client;
    if (client == null) return;
    try {
      await client.from('crash_reports').insert({
        ..._base(),
        'error': _truncate('$error', 2000),
        'stack': _truncate('$stackTrace', 8000),
        'context': context,
        'fatal': fatal,
      });
      AppLogger.i('TELEMETRY', 'crash report uploaded');
    } catch (e) {
      AppLogger.w('TELEMETRY', 'crash report dropped: $e');
    }
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}
