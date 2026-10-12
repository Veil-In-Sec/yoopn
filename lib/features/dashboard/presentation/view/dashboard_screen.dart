import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/view/screens/home_screen.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/promo_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    AppLogger.d('UI', 'DashboardScreen initState → request servers');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.d('UI', 'DashboardScreen postFrame → VpnServersRequested');
      if (mounted) context.read<VpnBloc>().add(const VpnServersRequested());
      if (mounted) context.read<VpnBloc>().add(const VpnTunnelSyncRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.d('UI', 'DashboardScreen build');
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        AppLogger.d('UI', 'DashboardScreen auth=${state.status} hasSession=${state.session != null}');
        if (state.status == AuthStatus.initial && state.session == null) {
          AppLogger.i('ROUTE', 'dashboard signed-out → auth');
          context.pushReplacement(AppPages.auth);
        }
      },
        child: const Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              HomeScreen(),
              PromoSheet(),
            ],
          ),
        ),
    );
  }
}
