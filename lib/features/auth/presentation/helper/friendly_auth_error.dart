import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps any auth failure to one short, actionable snackbar line.
///
/// Raw Supabase/platform text ("AuthException: ...", "Exception: ...",
/// socket dumps) must never reach the UI. Unknown errors fall through to a
/// generic line — never the raw `toString()`.
String friendlyAuthError(Object error) {
  var code = '';
  var message = '';
  if (error is AuthException) {
    code = (error.code ?? '').toLowerCase();
    message = error.message.toLowerCase();
  } else {
    message = error.toString().toLowerCase();
  }
  bool has(List<String> keys) =>
      keys.any(message.contains) ||
      (code.isNotEmpty && keys.any(code.contains));

  if (has([
    'invalid login credentials',
    'invalid_credentials',
    'invalid grant',
    'invalid email or password',
    'incorrect',
  ])) {
    return 'Incorrect email or password. Check both and try again.';
  }
  if (has(['email not confirmed', 'not confirmed', 'unconfirmed'])) {
    return 'Please confirm your email first — check your inbox for the verification link.';
  }
  if (has(['user not found', 'user_not_found'])) {
    return 'No account found for this email. Check it or create a new account.';
  }
  if (has(['otp expired', 'token has expired', 'otp_expired', 'token_expired'])) {
    return 'That code expired. Request a new one and try again.';
  }
  if (has([
    'invalid token',
    'invalid otp',
    'invalid_token',
    'token invalid',
    'token is invalid',
  ])) {
    return 'That code is invalid. Double-check it and try again.';
  }
  if (has(['weak password', 'password should be', 'password_too_short'])) {
    return 'Password is too weak. Use at least 6 characters.';
  }
  if (has([
    'already registered',
    'already exists',
    'user_already_exists',
    'email exists',
    'already in use',
  ])) {
    return 'An account with this email already exists. Try signing in instead.';
  }
  if (has([
    'rate limit',
    'too many requests',
    'too many attempts',
    'over_email_send_rate_limit',
    'over_request_rate_limit',
  ])) {
    return 'Too many attempts. Wait a minute and try again.';
  }
  if (has(['disabled'])) {
    return 'Signing in is currently unavailable. Try again later.';
  }
  if (has([
    'socketexception',
    'failed host',
    'no address associated',
    'network is unreachable',
    'no internet',
    'connection refused',
    'connection timed out',
    'timeout',
  ])) {
    return 'No internet connection. Check your connection and try again.';
  }
  if (has(['cancelled', 'canceled', 'dismissed', 'popup closed'])) {
    return 'Sign-in was cancelled.';
  }
  return 'Something went wrong. Please try again.';
}
