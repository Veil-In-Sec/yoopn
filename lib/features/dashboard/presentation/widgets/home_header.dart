import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';

/// Compact identity row. 1.1.1.1 keeps the account entry small so the power
/// button stays the hero.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final local = email.split('@').first;
    final parts = local
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((p) => p.isNotEmpty)
        .toList();

    final initials = parts.isEmpty
        ? 'U'
        : parts.take(2).map((p) => p[0]).join().toUpperCase();
    final name = parts.isEmpty
        ? 'there'
        : parts.first[0].toUpperCase() + parts.first.substring(1);

    return Row(
      children: [
        CircleAvatar(
          radius: 18.r,
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'YooPN',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                name,
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
        IconButton(
          tooltip: 'Help',
          onPressed: () {},
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.help_outline_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}