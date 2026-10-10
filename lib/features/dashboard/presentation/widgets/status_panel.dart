import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

/// Centered status readout above the power button (1.1.1.1 style):
/// one short headline, one supporting line, nothing else.
class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<VpnBloc, VpnState, (VpnStatus, String, DateTime?)>(
      selector: (state) =>
          (state.status, state.connectionDetail, state.connectedSince),
      builder: (context, selected) {
        final (status, detail, since) = selected;
        AppLogger.d('UI', 'StatusPanel status=$status detail=$detail');

        final connected = status == VpnStatus.connected;
        final connecting = status == VpnStatus.connecting;

        // While connecting show the live engine stage so a slow relay never
        // looks frozen; otherwise the static subtitle.
        final supporting = connecting && detail.isNotEmpty
            ? detail
            : status.subtitle;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // State badge, directly under the toggle button.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(
                  color: connected
                      ? AppColors.success
                      : connecting
                          ? AppColors.warning
                          : AppColors.disconnected,
                ),
                SizedBox(width: 8.w),
                Text(
                  connected
                      ? 'Protected'
                      : connecting
                          ? 'Connecting'
                          : 'Standby',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            // Reserve two lines so switching between status/subtitle never
            // nudges the toggle button.
            SizedBox(
              height: 34.h * 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // While connected the headline itself is the live
                  // session timer ("Connected for 00:12:34").
                  if (connected && since != null)
                    _ConnectedTimerTitle(since: since)
                  else
                    Text(
                      status.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26.sp,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  SizedBox(height: 4.h),
                  Text(
                    supporting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (connecting) ...[
              SizedBox(height: 4.h),
              _CancelLink(),
            ],
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8.r,
      height: 8.r,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Headline replacement while connected: ticks every second showing
/// "Connected for HH:MM:SS".
class _ConnectedTimerTitle extends StatefulWidget {
  const _ConnectedTimerTitle({required this.since});

  final DateTime since;

  @override
  State<_ConnectedTimerTitle> createState() => _ConnectedTimerTitleState();
}

class _ConnectedTimerTitleState extends State<_ConnectedTimerTitle> {
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
    final elapsed = DateTime.now().difference(widget.since);
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      'Connected for $h:$m:$s',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 26.sp,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Escape hatch while connecting — dispatches VpnToggled, which the bloc
/// turns into a cancel of the in-flight attempt.
class _CancelLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        AppLogger.i('UI', 'StatusPanel cancel tapped');
        context.read<VpnBloc>().add(const VpnToggled());
      },
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Cancel',
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}