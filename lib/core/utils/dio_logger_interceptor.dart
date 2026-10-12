import 'package:dio/dio.dart';
import 'package:yoopn/core/utils/app_logger.dart';

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
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.cancel) {
      AppLogger.w(
        'NET',
        '✖ ${err.type.name} ${err.requestOptions.method} '
        '${err.requestOptions.uri}',
      );
    } else {
      AppLogger.e(
        'NET',
        '✖ ${err.type.name} ${err.requestOptions.method} ${err.requestOptions.uri} | ${err.message}',
        err.error,
        err.stackTrace,
      );
    }
    super.onError(err, handler);
  }
}
