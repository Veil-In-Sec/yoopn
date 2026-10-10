import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Draggable promo sheet docked over home: rests at the bottom third, slides
/// up to near-full. Two sections — premium plan and rewarded ad. Actions are
/// placeholders for now (store purchase + AdMob come later).
class PromoSheet extends StatelessWidget {
  const PromoSheet({super.key});

  void _comingSoon(BuildContext context, String feature) {
    AppLogger.i('UI', 'Promo tapped → $feature (coming soon)');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature coming soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.24,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.24, 0.52, 0.95],
      builder: (_, controller) => Container(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          border: Border.all(color: AppColors.border),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.zero,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            _SectionLabel(text: 'Premium'),
            SizedBox(height: 4.h),
            _PromoOption(
              icon: Icons.workspace_premium_rounded,
              iconColor: AppColors.primary,
              iconBackground: AppColors.primaryContainer,
              title: 'Buy Premium Plan',
              subtitle: 'Faster servers, no limits',
              onTap: () => _comingSoon(context, 'Premium plan'),
            ),
            SizedBox(height: 8.h),
            const _Perk(text: 'Priority fastest servers'),
            const _Perk(text: 'No limits, no throttling'),
            const _Perk(text: 'More server selections'),
            const _Perk(text: 'More secure encrypted connection gateway'),
            Divider(height: 24.h, color: AppColors.divider),
            _SectionLabel(text: 'Advertisement'),
            SizedBox(height: 8.h),
            // Direct ad slot: swap this placeholder with the AdMob banner
            // widget (AdWidget) on integration. Not tappable — ads render
            // here inline, no reward flow.
            const _AdSlot(),
            // Second ad slot, revealed on slide-up / scroll.
            SizedBox(height: 16.h),
            _SectionLabel(text: 'Advertisement'),
            SizedBox(height: 8.h),
            const _AdSlot(),
          ],
        ),
      ),
    );
  }
}

/// Inline ad placeholder. Swap with the AdMob banner widget on integration.
class _AdSlot extends StatelessWidget {
  const _AdSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 96.h,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ad',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textHint,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Advertisement',
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, top: 4.h),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: AppColors.success,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoOption extends StatelessWidget {
  const _PromoOption({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(icon, color: iconColor, size: 24.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
