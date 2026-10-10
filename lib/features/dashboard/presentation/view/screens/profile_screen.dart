import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

/// Account setup: OAuth avatar when available, email/password management,
/// live tunnel state. Sign-out moved to the menu bottom.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.d('UI', 'ProfileScreen build');
    final email = context.select<AuthBloc, String>(
      (bloc) => bloc.state.user?.email ?? bloc.state.email,
    );
    final photoUrl = context.select<AuthBloc, String?>(
      (bloc) => bloc.state.user?.photoUrl,
    );
    final displayName = context.select<AuthBloc, String?>(
      (bloc) => bloc.state.user?.displayName,
    );
    // Promotion-friendly locals: headline prefers the name, tile falls back
    // to the setup prompt.
    final dn = displayName;
    final hasName = dn != null && dn.isNotEmpty;
    final headline =
        hasName ? dn : (email.isEmpty ? 'User profile' : email);

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          prev.errorMsg != curr.errorMsg || prev.message != curr.message,
      listener: (context, state) {
        final text = state.errorMsg ?? state.message;
        if (text == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(text),
              backgroundColor:
                  state.errorMsg != null ? AppColors.error : null,
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Spacing.vertical(12),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Account setup',
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Spacing.vertical(16),
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42.r,
                        backgroundColor: AppColors.primary,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        onBackgroundImageError: (error, stackTrace) {},
                        child: photoUrl == null
                            ? Icon(
                                Icons.person_rounded,
                                size: 46.r,
                                color: AppColors.onPrimary,
                              )
                            : null,
                      ),
                      Spacing.vertical(14),
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (hasName && email.isNotEmpty) ...[
                        Spacing.vertical(4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
                Spacing.vertical(12),
                _ActionTile(
                  icon: Icons.badge_rounded,
                  label: 'Change name',
                  value: (dn != null && dn.isNotEmpty)
                      ? dn
                      : 'Set a display name',
                  onTap: () => _editDialog(
                    context,
                    title: 'Change name',
                    hint: 'Display name',
                    keyboard: TextInputType.name,
                    obscure: false,
                    onSave: (v) => context.read<AuthBloc>().add(
                          AuthDisplayNameUpdateSubmitted(v),
                        ),
                  ),
                ),
                Spacing.vertical(12),
                _ActionTile(
                  icon: Icons.edit_rounded,
                  label: 'Change email',
                  value: 'Verification link goes to the new address',
                  onTap: () => _editDialog(
                    context,
                    title: 'Change email',
                    hint: 'New email address',
                    keyboard: TextInputType.emailAddress,
                    obscure: false,
                    onSave: (v) => context.read<AuthBloc>().add(
                          AuthEmailUpdateSubmitted(v),
                        ),
                  ),
                ),
                Spacing.vertical(12),
                _ActionTile(
                  icon: Icons.lock_rounded,
                  label: 'Change password',
                  value: 'At least 6 characters',
                  onTap: () => _editDialog(
                    context,
                    title: 'Change password',
                    hint: 'New password',
                    keyboard: TextInputType.visiblePassword,
                    obscure: true,
                    onSave: (v) => context.read<AuthBloc>().add(
                          AuthPasswordUpdateSubmitted(v),
                        ),
                  ),
                ),
                const Spacer(),
                Spacing.vertical(12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editDialog(
    BuildContext context, {
    required String title,
    required String hint,
    required TextInputType keyboard,
    required bool obscure,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: keyboard,
          obscureText: obscure,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) {
            final value = controller.text.trim();
            Navigator.of(dialogContext).pop();
            if (value.isNotEmpty) onSave(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(dialogContext).pop();
              if (value.isNotEmpty) onSave(value);
            },
            child: const Text('Save'),
          ),
        ],
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16.r),
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
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
