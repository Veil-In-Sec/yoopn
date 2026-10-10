import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/connect_button.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/home_header.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/status_panel.dart';

/// Home screen, structured like 1.1.1.1: one dominant toggle with the
/// status directly above it and the location picker directly below, so the
/// primary action is unmissable. Account details live in the drawer.
///
/// Layout notes: [SliverFillRemaining] (not LayoutBuilder/IntrinsicHeight)
/// gives the Spacers a definite height while staying scroll-safe. The old
/// LayoutBuilder sandwich tripped a framework `debugNeedsLayout` assertion
/// on every hot reload/restart, leaving a blank screen behind.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.d('UI', 'HomeScreen build');
    return SafeArea(
      bottom: false,
      child: Padding(
        // Bottom inset clears the floating action area.
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  const HomeHeader(),
                  SizedBox(height: 20.h),
                  const _FreeTitle(),
                  SizedBox(height: 20.h),
                  const ConnectButton(),
                  SizedBox(height: 12.h),
                  const StatusPanel(),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big title pinned to the top of the body, under the app bar.
class _FreeTitle extends StatelessWidget {
  const _FreeTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'FREE',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 60.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        color: AppColors.textSecondary,
      ),
    );
  }
}
