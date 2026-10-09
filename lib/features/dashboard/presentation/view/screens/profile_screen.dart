import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.d('UI', 'ProfileScreen build');
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
              // Live tunnel state instead of a hardcoded claim.
              BlocBuilder<VpnBloc, VpnState>(
                buildWhen: (prev, curr) =>
                    prev.status != curr.status ||
                    prev.server != curr.server ||
                    prev.connectedSince != curr.connectedSince,
                builder: (context, state) {
                  final server = state.selectedServer;
                  final connected = state.status == VpnStatus.connected;
                  final protection = switch (state.status) {
                    VpnStatus.connected => 'Secure — connected',
                    VpnStatus.connecting => 'Connecting…',
                    VpnStatus.disconnected => 'Not protected',
                  };
                  final region = server == null
                      ? 'Unknown'
                      : server.name.isEmpty
                          ? 'Unknown'
                          : '${server.flag} ${server.name}';
                  return Column(
                    children: [
                      _InfoTile(
                        icon: Icons.privacy_tip_rounded,
                        label: 'Protection',
                        value: protection,
                        valueColor: connected
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                      Spacing.vertical(12),
                      _InfoTile(
                        icon: Icons.language_rounded,
                        label: 'Region',
                        value: region,
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              _SignOutButton(email: email),
              Spacing.vertical(12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Disconnects the tunnel, then signs out and returns to the auth screen.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.email});

  final String email;

  Future<void> _confirm(BuildContext context) async {
    AppLogger.i('UI', 'Profile sign-out tapped');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Sign out?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'The VPN tunnel will disconnect and you will return to the '
          'login screen.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Never leave the OS tunnel running past the session.
    final vpnBloc = context.read<VpnBloc>();
    if (vpnBloc.state.status != VpnStatus.disconnected) {
      AppLogger.i('UI', 'sign-out: disconnecting tunnel first');
      vpnBloc.add(const VpnToggled());
    }
    context.read<AuthBloc>().add(const AuthSignOutSubmitted());
    AppLogger.i('ROUTE', 'sign-out → auth');
    context.go(AppPages.auth);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirm(context),
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        label: Text(
          'Sign out',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.error,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
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
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

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
                    color: valueColor ?? AppColors.textPrimary,
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