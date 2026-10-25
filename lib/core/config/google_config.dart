import 'package:flutter/foundation.dart';

/// Native Google sign-in (Credential Manager one-tap) configuration.
///
/// Follows the [AdConfig]/owner-config pattern: real values ship via
/// `--dart-define`. When the client ID is absent the app falls back to the
/// Supabase system-browser OAuth flow, so behavior is unchanged until the
/// owner registers the Google Cloud OAuth clients (decision #8).
class GoogleConfig {
  GoogleConfig._();

  /// WEB application OAuth client ID from Google Cloud Console.
  ///
  /// The Web client — not the Android client — is what the SDK needs as
  /// `serverClientId`; the Android client is matched by package name +
  /// SHA-1 certificate fingerprint and is never passed to this app.
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Whether the native one-tap flow may be attempted on this runtime.
  ///
  /// Android-only for now (decision #2), never on web; other platforms keep
  /// using the browser flow.
  static bool get nativeConfigured =>
      webClientId.isNotEmpty &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;
}
