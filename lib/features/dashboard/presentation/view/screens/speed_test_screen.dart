import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/core/utils/dependency_injection.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/speed_test_cubit.dart';

class SpeedTestScreen extends StatelessWidget {
  const SpeedTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.d('UI', 'SpeedTestScreen build → create SpeedTestCubit');
    return BlocProvider(
      create: (_) {
        AppLogger.d('SPEED', 'SpeedTestCubit created for screen');
        return sl<SpeedTestCubit>();
      },
      child: const _SpeedTestBody(),
    );
  }
}

class _SpeedTestBody extends StatelessWidget {
  const _SpeedTestBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spacing.vertical(12),
              Text(
                'Speed Test',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacing.vertical(8),
              BlocSelector<SpeedTestCubit, SpeedTestState, String?>(
                selector: (s) => s.error,
                builder: (_, error) => Text(
                  error ?? 'Check your connection quality in real time.',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: error != null
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              Spacing.vertical(24),
              BlocBuilder<SpeedTestCubit, SpeedTestState>(
                builder: (_, state) {
                  final running =
                      state.status == SpeedTestStatus.running;
                  final result = state.result;
                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          size: 52.r,
                          color: AppColors.primary,
                        ),
                        Spacing.vertical(14),
                        if (running) ...[
                          LinearProgressIndicator(value: state.progress),
                          Spacing.vertical(12),
                          Text(
                            state.phase.isEmpty
                                ? 'Testing… ${(state.progress * 100).toStringAsFixed(0)}%'
                                : '${state.phase} ${(state.progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ] else ...[
                          Text(
                            result != null
                                ? result.downloadText
                                : '— Mbps',
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Spacing.vertical(6),
                          Text(
                            result?.testedAt != null
                                ? 'Download speed • just now'
                                : 'Download speed',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              Spacing.vertical(24),
              BlocSelector<SpeedTestCubit, SpeedTestState, SpeedTestState>(
                selector: (s) => s,
                builder: (_, state) => Row(
                  children: [
                    _MetricCard(
                      label: 'Ping',
                      value: state.result != null
                          ? state.result!.pingText
                          : '— ms',
                    ),
                    Spacing.horizontal(12),
                    _MetricCard(
                      label: 'Upload',
                      value: state.result != null
                          ? state.result!.uploadText
                          : '— Mbps',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: BlocSelector<SpeedTestCubit, SpeedTestState, bool>(
                  selector: (s) => s.status == SpeedTestStatus.running,
                  builder: (context, running) => ElevatedButton.icon(
                    onPressed: running
                        ? null
                        : () {
                            AppLogger.i('UI', 'SpeedTest Run tapped');
                            context.read<SpeedTestCubit>().run();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    icon: running
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      running ? 'Testing…' : 'Run Speed Test',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
            ),
            Spacing.vertical(8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
