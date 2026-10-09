import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthBloc, String>(
      (bloc) => bloc.state.user?.email ?? bloc.state.email,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spacing.vertical(12),
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacing.vertical(16),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42.r,
                      backgroundColor: AppColors.primary,
                      child: Icon(
                        Icons.person_rounded,
                        size: 46.r,
                        color: AppColors.onPrimary,
                      ),
                    ),
                    Spacing.vertical(14),
                    Text(
                      email.isEmpty ? 'User profile' : email,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Spacing.vertical(28),
              _InfoTile(
                icon: Icons.email_rounded,
                label: 'Email',
                value: email.isEmpty ? 'No email available' : email,
              ),
              Spacing.vertical(12),
              _InfoTile(
                icon: Icons.privacy_tip_rounded,
                label: 'Protection',
                value: 'Secure VPN enabled',
              ),
              Spacing.vertical(12),
              _InfoTile(
                icon: Icons.language_rounded,
                label: 'Region',
                value: 'Global',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          Spacing.horizontal(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                Spacing.vertical(4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
