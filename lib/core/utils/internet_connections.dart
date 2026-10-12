import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:yoopn/core/utils/app_logger.dart';

class InternetUtils {
  InternetUtils._();

  static final Connectivity _connectivity = Connectivity();

  static Future<bool> isConnected() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      AppLogger.d('NET', 'connectivity check → $connectivityResult');

      if (connectivityResult.contains(ConnectivityResult.none)) {
        AppLogger.w('NET', 'no network interface (none)');
        return false;
      }

      return await _hasInternetAccess();
    } catch (e, st) {
      AppLogger.e('NET', 'isConnected failed', e, st);
      return false;
    }
  }

  static Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));

      final ok = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      AppLogger.d('NET', 'DNS google.com reachable=$ok (${result.length} records)');
      return ok;
    } catch (e) {
      AppLogger.w('NET', 'DNS probe failed — offline', e);
      return false;
    }
  }

  static Stream<List<ConnectivityResult>> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }

  static Future<List<ConnectivityResult>> get connectionType async {
    return await _connectivity.checkConnectivity();
  }
}
