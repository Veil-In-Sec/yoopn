import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the status changes, never on server changes.
    return BlocSelector<VpnBloc, VpnState, VpnStatus>(
      selector: (state) => state.status,
      builder: (context, status) {
        final active = status == VpnStatus.connected;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey(status),
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8.r,
                      height: 8.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      active ? 'Secure' : 'Standby',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                status.title,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                status.subtitle,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              if (active) ...[
                SizedBox(height: 8.h),
                const _ConnectionTimer(),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Ticks every second while connected, showing session duration.
/// Rebuilds only itself — never the connect button or server list.
class _ConnectionTimer extends StatefulWidget {
  const _ConnectionTimer();

  @override
  State<_ConnectionTimer> createState() => _ConnectionTimerState();
}

class _ConnectionTimerState extends State<_ConnectionTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = context.select<VpnBloc, DateTime?>(
      (bloc) => bloc.state.connectedSince,
    );
    if (since == null) return const SizedBox.shrink();
    final elapsed = DateTime.now().difference(since);
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      'Connected $h:$m:$s',
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    );
  }
}
