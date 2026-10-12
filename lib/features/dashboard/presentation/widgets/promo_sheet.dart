import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/ads/ad_carousel_widget.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';

class PromoSheet extends StatelessWidget {
  const PromoSheet({super.key});

  VpnServer _selected(List<VpnServer> servers, String id) {
    for (final s in servers) {
      if (s.matchesId(id)) return s;
    }
    return servers.isNotEmpty
        ? servers.first
        : const VpnServer(name: 'United States', flag: '🇺🇸');
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(text: 'Servers'),
            Spacing.vertical(4),
            BlocBuilder<VpnBloc, VpnState>(
              buildWhen: (prev, curr) =>
                  prev.server != curr.server || prev.servers != curr.servers,
              builder: (context, state) {
                final selected = _selected(state.servers, state.server);
                return _PromoOption(
                  icon: Icons.dns_rounded,
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.primaryContainer,
                  title: '${selected.flag} ${selected.name}',
                  subtitle: selected.isVpnGate
                      ? '${selected.hostName} • ${selected.speedText} — tap to change'
                      : 'Tap to choose a server',
                  onTap: () => context.push(AppPages.servers),
                );
              },
            ),
            Divider(height: 24.h, color: AppColors.divider),
            _SectionLabel(text: 'Advertisement'),
            Spacing.vertical(8),
            const AdCarouselWidget(),
            Spacing.vertical(12),
            _SectionLabel(text: 'Advertisement'),
            Spacing.vertical(8),
            const AdCarouselWidget(),
            Spacing.vertical(8),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

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
            Spacing.horizontal(12),
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
                  Spacing.vertical(2),
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
