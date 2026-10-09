import 'dart:math';

import 'package:dio/dio.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Result of one live speed-test run.
class SpeedTestResult {
  const SpeedTestResult({
    required this.downloadMbps,
    required this.pingMs,
    this.uploadMbps = 0,
    this.testedAt,
  });

  final double downloadMbps;
  final double uploadMbps;
  final int pingMs;
  final DateTime? testedAt;

  String get downloadText => '${downloadMbps.toStringAsFixed(1)} Mbps';
  String get uploadText => '${uploadMbps.toStringAsFixed(1)} Mbps';
  String get pingText => '$pingMs ms';
}

abstract interface class SpeedTestDataSource {
  Future<SpeedTestResult> run({
    void Function(double progress, String phase)? onProgress,
  });
}

/// Real measurement over HTTPS (no VPNGate dependency):
/// - ping: 3x GET `generate_204`, averaged.
/// - download: 10 MB from Cloudflare with progress callbacks.
/// - upload: 2 MB POST to Cloudflare with progress callbacks.
class LiveSpeedTestDataSource implements SpeedTestDataSource {
  LiveSpeedTestDataSource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
            ),
          );

  static const pingUrl = 'https://www.google.com/generate_204';
  static const downloadUrl =
      'https://speed.cloudflare.com/__down?bytes=10000000';
  static const uploadUrl = 'https://speed.cloudflare.com/__up';

  final Dio _dio;

  @override
  Future<SpeedTestResult> run({
    void Function(double progress, String phase)? onProgress,
  }) async {
    AppLogger.i('SPEED', 'run start');
    try {
      onProgress?.call(0.05, 'Pinging…');
      final pingMs = await _measurePing();
      AppLogger.i('SPEED', 'ping=${pingMs}ms');
      onProgress?.call(0.2, 'Measuring download…');
      AppLogger.d('SPEED', 'download start (10MB cloudflare)…');
      final downloadMbps = await _measureDownload(onProgress);
      AppLogger.i('SPEED', 'download=${downloadMbps.toStringAsFixed(2)} Mbps');
      onProgress?.call(0.8, 'Measuring upload…');
      AppLogger.d('SPEED', 'upload start (2MB)…');
      final uploadMbps = await _measureUpload(onProgress);
      AppLogger.i('SPEED', 'upload=${uploadMbps.toStringAsFixed(2)} Mbps');
      onProgress?.call(1, 'Done');
      return SpeedTestResult(
        downloadMbps: downloadMbps,
        uploadMbps: uploadMbps,
        pingMs: pingMs,
        testedAt: DateTime.now(),
      );
    } on VpnException {
      AppLogger.w('SPEED', 'run VpnException (rethrow)');
      rethrow;
    } catch (e, st) {
      AppLogger.e('SPEED', 'run failed', e, st);
      throw VpnException('speed-test', 'Speed test failed: $e', e);
    }
  }

  Future<int> _measurePing() async {
    final samples = <int>[];
    for (var i = 0; i < 3; i++) {
      final sw = Stopwatch()..start();
      await _dio.get<void>(pingUrl);
      sw.stop();
      samples.add(sw.elapsedMilliseconds);
    }
    samples.sort();
    return samples[samples.length ~/ 2]; // median
  }

  Future<double> _measureDownload(
    void Function(double progress, String phase)? onProgress,
  ) async {
    final sw = Stopwatch()..start();
    var received = 0;
    await _dio.get<List<int>>(
      downloadUrl,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (count, total) {
        received = count;
        if (total > 0) {
          onProgress?.call(0.2 + 0.5 * (count / total), 'Measuring download…');
        }
      },
    );
    sw.stop();
    return mbps(received, sw.elapsedMicroseconds);
  }

  Future<double> _measureUpload(
    void Function(double progress, String phase)? onProgress,
  ) async {
    // 2 MB of pseudo-random bytes; content itself is irrelevant.
    final rng = Random(42);
    final payload = List<int>.generate(2 * 1024 * 1024, (_) => rng.nextInt(256));
    final sw = Stopwatch()..start();
    await _dio.post<void>(
      uploadUrl,
      data: Stream.fromIterable([payload]),
      options: Options(
        headers: const {'Content-Type': 'application/octet-stream'},
      ),
      onSendProgress: (count, total) {
        if (total > 0) {
          onProgress?.call(0.8 + 0.15 * (count / total), 'Measuring upload…');
        }
      },
    );
    sw.stop();
    return mbps(payload.length, sw.elapsedMicroseconds);
  }

  /// Bytes + microseconds -> megabits per second. Pure helper, unit-tested.
  static double mbps(int bytes, int microseconds) {
    if (bytes <= 0 || microseconds <= 0) return 0;
    return (bytes * 8 / 1000000) / (microseconds / 1000000);
  }
}
