import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class InternetUtils {
  InternetUtils._();

  static final Connectivity _connectivity = Connectivity();

  /// Checks whether the device has an active internet connection.
  static Future<bool> isConnected() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      return await _hasInternetAccess();
    } catch (e) {
      return false;
    }
  }

  /// Checks whether the internet is actually reachable.
  static Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Returns a stream whenever the network connection changes.
  static Stream<List<ConnectivityResult>> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }

  /// Returns the current connection type.
  static Future<List<ConnectivityResult>> get connectionType async {
    return await _connectivity.checkConnectivity();
  }
}
