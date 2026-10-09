import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/core/telemetry/supabase_telemetry.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/data/datasources/speed_test_data_source.dart';

enum SpeedTestStatus { initial, running, success, failure }

class SpeedTestState {
  const SpeedTestState({
    this.status = SpeedTestStatus.initial,
    this.progress = 0,
    this.phase = '',
    this.result,
    this.error,
  });

  final SpeedTestStatus status;
  final double progress;
  final String phase;
  final SpeedTestResult? result;
  final String? error;

  SpeedTestState copyWith({
    SpeedTestStatus? status,
    double? progress,
    String? phase,
    SpeedTestResult? result,
    String? error,
  }) => SpeedTestState(
    status: status ?? this.status,
    progress: progress ?? this.progress,
    phase: phase ?? this.phase,
    result: result ?? this.result,
    error: error,
  );
}

class SpeedTestCubit extends Cubit<SpeedTestState> {
  SpeedTestCubit({required this.dataSource}) : super(const SpeedTestState());

  final SpeedTestDataSource dataSource;

  Future<void> run() async {
    if (state.status == SpeedTestStatus.running) {
      AppLogger.d('SPEED', 'run ignored — already running');
      return;
    }
    AppLogger.i('SPEED', 'SpeedTestCubit.run start');
    emit(
      const SpeedTestState(status: SpeedTestStatus.running, progress: 0),
    );
    try {
      final result = await dataSource.run(
        onProgress: (progress, phase) {
          AppLogger.d('SPEED', 'progress ${(progress * 100).toStringAsFixed(0)}% $phase');
          if (!isClosed) {
            emit(
              state.copyWith(progress: progress, phase: phase),
            );
          }
        },
      );
      if (!isClosed) {
        AppLogger.i('SPEED', 'success dl=${result.downloadText} up=${result.uploadText} ping=${result.pingText}');
        Telemetry.track('speed_test_result', {
          'download_mbps': result.downloadMbps,
          'upload_mbps': result.uploadMbps,
          'ping_ms': result.pingMs,
        });
        emit(
          SpeedTestState(
            status: SpeedTestStatus.success,
            progress: 1,
            phase: 'Done',
            result: result,
          ),
        );
      }
    } catch (e, st) {
      AppLogger.e('SPEED', 'SpeedTestCubit failed', e, st);
      if (!isClosed) {
        emit(
          SpeedTestState(
            status: SpeedTestStatus.failure,
            error: VpnFailure.from(e).message,
            result: state.result,
          ),
        );
      }
    }
  }
}
