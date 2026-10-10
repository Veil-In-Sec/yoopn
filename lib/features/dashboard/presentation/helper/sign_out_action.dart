import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

/// Shared sign-out flow (drawer + profile use the same one): confirm,
/// disconnect the tunnel first, sign out, return to auth.
Future<void> confirmAndSignOut(BuildContext context) async {
  AppLogger.i('UI', 'sign-out tapped');
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
      content: const Text(
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
