import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/view/screens/home_screen.dart';
import 'package:yoopn/features/dashboard/presentation/view/screens/profile_screen.dart';
import 'package:yoopn/features/dashboard/presentation/view/screens/speed_test_screen.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/app_bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ValueNotifier<int> _index = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // Load the live VPNGate relay list once per dashboard entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<VpnBloc>().add(const VpnServersRequested());
    });
  }

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == AuthStatus.initial && state.session == null) {
          context.pushReplacement(AppPages.auth);
        }
      },
      child: BlocSelector<AuthBloc, AuthState, String>(
        selector: (state) => state.user?.email ?? state.email,
        builder: (context, email) {
          final screens = [
            HomeScreen(email: email),
            const SpeedTestScreen(),
            const ProfileScreen(),
          ];

          return Scaffold(
            backgroundColor: AppColors.background,
            extendBody: true,
            body: ValueListenableBuilder<int>(
              valueListenable: _index,
              builder: (_, i, _) => IndexedStack(index: i, children: screens),
            ),
            bottomNavigationBar: AppBottomNav(index: _index),
          );
        },
      ),
    );
  }
}
