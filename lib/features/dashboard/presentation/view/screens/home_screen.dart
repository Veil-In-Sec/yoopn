import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/ads/ad_carousel_widget.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/connect_button.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/home_header.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/status_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.d('UI', 'HomeScreen build');
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  const HomeHeader(),
                  Spacing.vertical(12),
                  const Center(child: AdCarouselWidget()),
                  Spacing.vertical(12),
                  const _FreeTitle(),
                  Spacing.vertical(20),
                  const ConnectButton(),
                  Spacing.vertical(12),
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

class _FreeTitle extends StatelessWidget {
  const _FreeTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'YooPN+',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 60.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        color: AppColors.primary,
      ),
    );
  }
}
