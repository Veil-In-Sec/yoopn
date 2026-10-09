import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Production telemetry backed by Supabase Postgres.
///
/// Supabase ships no Crashlytics product, so this service writes:
/// - user/product events → `analytics_events`
/// - uncaught errors + VPN/auth failures → `crash_reports`
///
/// Review them in the Supabase dashboard (SQL editor / Table editor).
/// See `supabase/migrations/001_app_telemetry.sql` for the schema and
/// `supabase/README.md` for review queries.
///
/// Guarantees:
/// - Never throws: every call is guarded, safe from blocs, UI and tests.
/// - No-op until Supabase is initialized (unit tests stay offline-safe).
/// - Privacy: callers MUST mask emails ([AppLogger.maskEmail]) and MUST
///   never pass passwords, OTP codes, tokens or OpenVPN configs.
class Telemetry {
  Telemetry._();

  /// Master switch (e.g. disable for automated tests).
  static bool enabled = true;

  /// Keep in sync with `pubspec.yaml` version.
  static String appVersion = '1.0.0+1';

  static String? _sessionId;

  /// Stable id for one app launch; groups events of a session together.
  static String get sessionId {
    return _sessionId ??= '${DateTime.now().millisecondsSinceEpoch}-'
        '${Random().nextInt(1 << 32).toRadixString(16)}';
  }

  /// Call once after `Supabase.initialize` in `main()`.
  static void init() {
    _sessionId = null; // fresh id per launch
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
      return null; // not initialized (tests, early boot)
    }
  }

  static Map<String, dynamic> _base() => {
    'session_id': sessionId,
    'platform': defaultTargetPlatform.name,
    'app_version': appVersion,
    'user_id': _client?.auth.currentUser?.id,
  };

  /// Fire-and-forget analytics event. Safe to call without awaiting.
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
      // Telemetry must never break the app (offline, missing table, RLS).
      AppLogger.w('TELEMETRY', 'track $event dropped: $e');
    }
  }

  /// Shorthand for screen views.
  static Future<void> screen(String name) =>
      track('screen_view', {'screen': name});

  /// Crash / fatal-error report. Also mirrors to [AppLogger.e] so the
  /// console + DevTools keep the full trace during development.
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
