import 'package:dio/dio.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Logs every HTTP call made through Dio.
///
/// - VPNGate CSV list (`vpngate.net/api/iphone/`)
/// - Speed-test endpoints (google `generate_204`, cloudflare `__down/__up`)
/// Bodies are truncated — 10MB downloads log byte counts, not content.
class DioLoggerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.i(
      'NET',
      '→ ${options.method} ${options.uri} | query=${AppLogger.short(options.queryParameters, 200)}',
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final data = response.data;
    final size = data is String
        ? '${data.length} chars'
        : data is List
            ? '${data.length} bytes'
            : AppLogger.short(data, 200);
    AppLogger.i(
      'NET',
      '← ${response.statusCode} ${response.requestOptions.uri} | $size',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.e(
      'NET',
      '✖ ${err.type.name} ${err.requestOptions.method} ${err.requestOptions.uri} | ${err.message}',
      err.error,
      err.stackTrace,
    );
    super.onError(err, handler);
  }
}
