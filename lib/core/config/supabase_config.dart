import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yoopn/core/utils/app_logger.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const _kUrl = String.fromEnvironment('SUPABASE_URL');
  static const _kKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _kRedirect = String.fromEnvironment('REDIRECT_URL');

  static bool _loaded = false;
  static String? _source;

  static String get source => _source ?? 'none';

  static bool get fromBundledAsset => _source == '.env';

  static Future<void> load() async {
    _loaded = false;
    AppLogger.d('CONFIG', 'resolving Supabase config…');

    if (_kUrl.isNotEmpty && _kKey.isNotEmpty) {
      _loaded = true;
      _source = 'dart-define';
      AppLogger.i('CONFIG', 'Supabase config from --dart-define (not bundled)');
      return;
    }

    try {
      await dotenv.load(fileName: '.env');
      final url = dotenv.env['SUPABASE_URL'];
      final key = dotenv.env['SUPABASE_ANON_KEY'];
      final redirect = dotenv.env['REDIRECT_URL'];
      if (url != null && url.isNotEmpty && key != null && key.isNotEmpty) {
        _loaded = true;
        _source = '.env';
        AppLogger.i(
          'CONFIG',
          'Supabase config from .env asset (bundled in this build)',
        );
        if (kReleaseMode) {
          AppLogger.w(
            'CONFIG',
            'Release build is using the bundled .env. Pass --dart-define '
            'SUPABASE_URL/SUPABASE_ANON_KEY to keep the key out of the APK.',
          );
        }
      } else {
        AppLogger.w('CONFIG', '.env loaded but missing SUPABASE_URL/ANON_KEY');
      }
      AppLogger.d(
        'CONFIG',
        'env keys → url=${url != null} anonKey=${(key ?? '').isNotEmpty} '
        'redirect=${redirect ?? '<missing>'}',
      );
    } catch (e, st) {
      AppLogger.e('CONFIG', 'dotenv load failed', e, st);
      AppLogger.e(
        'CONFIG',
        'No config available. Pass --dart-define=SUPABASE_URL=… '
        'SUPABASE_ANON_KEY=… or add a .env file.',
      );
    }
  }

  static String get url => _require('SUPABASE_URL', _firstNonEmpty([_kUrl, _env('SUPABASE_URL')]));

  static String get publishableKey => _require(
        'SUPABASE_ANON_KEY',
        _firstNonEmpty([_kKey, _env('SUPABASE_ANON_KEY')]),
      );

  static String get redirectUrl => _require(
        'REDIRECT_URL',
        _firstNonEmpty([_kRedirect, _env('REDIRECT_URL')]),
      );

  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static String _require(String name, String? value) {
    if (value == null || value.isEmpty) {
      final where = _loaded ? _source! : 'nowhere (config not loaded)';
      throw StateError(
        '$name is not configured ($where). Provide it via --dart-define '
        'or a .env file.',
      );
    }
    return value;
  }
}