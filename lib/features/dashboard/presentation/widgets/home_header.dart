import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/themes/app_colors.dart';

/// Home app bar: app name top-left, hamburger menu top-right.
/// The hamburger opens the menu page (plan, account, logout, documents).
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'YooPN',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Menu',
          onPressed: () => context.push(AppPages.menu),
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.menu_rounded,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
