import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:yoopn/core/resources/app_assets.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

/// Splash doubles as the prefetch gate: the VPNGate CSV download starts
/// here, and navigation waits until the list has settled (loaded/failed)
/// or the safety timeout fires — so Home always opens with servers ready
/// (or an honest error + Retry), never with a spinner.
///
/// Nothing here can hang: the refresh budget settles the foreground in ≤2s,
/// and [_gateTimeout] caps the wait even if the bloc never answers.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _gateTimeout = Duration(seconds: 6);

  String? _pendingRoute;
  bool _serversDone = false;
  bool _timedOut = false;
  bool _navigated = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final vpn = context.read<VpnBloc>();
    // Already settled (warm restart)? Don't wait for an event that already
    // fired — a listener only runs on *changes*.
    _serversDone = vpn.state.serversStatus == VpnServersStatus.loaded ||
        vpn.state.serversStatus == VpnServersStatus.failure;
    AppLogger.i('UI', 'SplashScreen prefetch servers (settled=$_serversDone)');
    vpn.add(const VpnServersRequested());
    _timer = Timer(_gateTimeout, () {
      if (!mounted) return;
      AppLogger.w('UI', 'SplashScreen gate timeout — proceeding anyway');
      setState(() {
        _timedOut = true;
      });
      _maybeGo();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resolveRoute(String route) {
    _pendingRoute = route;
    _maybeGo();
  }

  void _maybeGo() {
    if (_navigated || _pendingRoute == null) return;
    if (!_serversDone && !_timedOut) {
      AppLogger.d('UI', 'SplashScreen holding for servers');
      return;
    }
    _navigated = true;
    _timer?.cancel();
    final route = _pendingRoute!;
    AppLogger.i('UI', 'SplashScreen → $route (serversDone=$_serversDone)');
    context.pushReplacement(route);
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.d('UI', 'SplashScreen build');
    return MultiBlocListener(
      listeners: [
        BlocListener<SplashBloc, SplashState>(
          listener: (context, state) {
            AppLogger.i('UI', 'SplashScreen state → ${state.status}');
            switch (state.status) {
              case SplashStatus.authenticated:
                AppLogger.i('ROUTE', 'splash → home');
                _resolveRoute(AppPages.home);
                break;

              case SplashStatus.unauthenticated:
                AppLogger.i('ROUTE', 'splash → auth');
                _resolveRoute(AppPages.auth);
                break;

              case SplashStatus.error:
                AppLogger.e('UI', 'SplashScreen error: ${state.errorMsg}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMsg ?? 'Something went wrong'),
                    action: SnackBarAction(
                      label: "Retry",
                      onPressed: () =>
                          context.read<SplashBloc>().add(const AppStarted()),
                    ),
                  ),
                );
                _resolveRoute(AppPages.auth);
                break;

              case SplashStatus.loading:
                break;
            }
          },
        ),
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state.status == AuthStatus.success && state.session != null) {
              AppLogger.i('ROUTE', 'auth session (from splash) → home');
              _resolveRoute(AppPages.home);
            }
          },
        ),
        BlocListener<VpnBloc, VpnState>(
          listenWhen: (prev, curr) =>
              prev.serversStatus != curr.serversStatus,
          listener: (context, state) {
            if (state.serversStatus == VpnServersStatus.loaded ||
                state.serversStatus == VpnServersStatus.failure) {
              AppLogger.i(
                'UI',
                'SplashScreen servers settled (${state.serversStatus})',
              );
              setState(() {
                _serversDone = true;
              });
              _maybeGo();
            }
          },
        ),
      ],
      child: Scaffold(
        body: Center(
          child: Lottie.asset(
            AppAssets.splashAnimationLogo,
            repeat: false,
            height: 300.h,
            width: 300.w,
          ),
        ),
      ),
    );
  }
}
