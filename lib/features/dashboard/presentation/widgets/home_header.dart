import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final parts = email
        .split('@')
        .first
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((p) => p.isNotEmpty)
        .toList();

    final initials = parts.isEmpty
        ? 'U'
        : parts.take(2).map((p) => p[0]).join().toUpperCase();

    // "john.doe@mail.com" -> "John"
    final name = parts.isEmpty
        ? 'there'
        : parts.first[0].toUpperCase() + parts.first.substring(1);

    return Row(
      children: [
        CircleAvatar(
          radius: 22.r,
          backgroundColor: AppColors.primary,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.onPrimary,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Need help?',
          onPressed: () {},
          icon: const Icon(
            Icons.help_outline_rounded,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}