import 'package:yoopn/core/utils/app_logger.dart';

class VpnException implements Exception {
  const VpnException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'VpnException($code): $message';
}

class VpnFailure {
  const VpnFailure(this.code, this.message);

  final String code;
  final String message;

  static const network = VpnFailure(
    'network',
    'No connection. Showing saved servers.',
  );
  static const server = VpnFailure(
    'server',
    'VPNGate is unreachable right now. Showing saved servers.',
  );
  static const cacheEmpty = VpnFailure(
    'cache-empty',
    'No saved servers yet. Connect to the internet and refresh.',
  );
  static const unknown = VpnFailure(
    'unknown',
    'Something went wrong. Please try again.',
  );

  factory VpnFailure.from(Object error) {
    final mapped = _map(error);
    AppLogger.w('VPN', 'failure mapped ${error.runtimeType} → ${mapped.code}: ${mapped.message}');
    return mapped;
  }

  static VpnFailure _map(Object error) {
    if (error is VpnFailure) return error;
    if (error is VpnException) return VpnFailure(error.code, error.message);
    final text = error.toString();
    if (text.contains('VPNGate request failed') ||
        text.contains('SocketException') ||
        text.contains('Connection closed') ||
        text.contains('TimeoutException')) {
      return VpnFailure.network;
    }
    return VpnFailure.unknown;
  }

  @override
  String toString() => message;
}
