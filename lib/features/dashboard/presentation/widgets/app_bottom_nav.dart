import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.index});

  final ValueNotifier<int> index;

  static const List<(IconData, String)> _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.speed_rounded, 'Speed Test'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(18.w, 0, 18.w, 14.h),
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (_, selected, _) {
            return Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (selected == i) return;
                        HapticFeedback.selectionClick();
                        index.value = i;
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: selected == i
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _items[i].$1,
                              size: 24.r,
                              color: selected == i
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              _items[i].$2,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: selected == i
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected == i
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}