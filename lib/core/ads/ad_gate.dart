import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/ads/rewarded_ad_manager.dart';
import 'package:yoopn/core/themes/app_colors.dart';

const Duration kAdGateDuration = Duration(seconds: 30);

bool _showing = false;
Future<void>? _gateFlight;

Future<void> showAdGate(
  BuildContext context, {
  required String title,
  String subtitle = 'Your request continues when the video finishes',
}) {
  // Concurrent callers JOIN the in-flight gate instead of bypassing it.
  final flight = _gateFlight;
  if (flight != null) return flight;
  final future = _runGate(context, title: title, subtitle: subtitle);
  _gateFlight = future;
  future.whenComplete(() {
    if (identical(_gateFlight, future)) {
      _gateFlight = null;
      _showing = false;
    }
  });
  return future;
}

Future<void> _runGate(
  BuildContext context, {
  required String title,
  required String subtitle,
}) async {
  if (_showing) return;
  _showing = true;
  try {
    unawaited(RewardedAdManager.instance.show());
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdGateDialog(title: title, subtitle: subtitle),
    );
  } finally {
    _showing = false;
  }
}

class _AdGateDialog extends StatefulWidget {
  const _AdGateDialog({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  State<_AdGateDialog> createState() => _AdGateDialogState();
}

class _AdGateDialogState extends State<_AdGateDialog> {
  late int _remaining = kAdGateDuration.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _timer?.cancel();
        Navigator.of(context).pop();
        return;
      }
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        1 - _remaining / kAdGateDuration.inSeconds.clamp(1, 1 << 30);
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(28.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'AD',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Spacing.vertical(16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacing.vertical(6),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              Spacing.vertical(20),
              Text(
                '$_remaining s',
                style: TextStyle(
                  fontSize: 40.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Spacing.vertical(12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8.h,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.primary,
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
