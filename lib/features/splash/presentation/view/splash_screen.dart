import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:yoopn/core/resources/app_assets.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
                context.pushReplacement(AppPages.home);
                break;

              case SplashStatus.unauthenticated:
                AppLogger.i('ROUTE', 'splash → auth');
                context.pushReplacement(AppPages.auth);
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
                context.pushReplacement(AppPages.auth);
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
              context.pushReplacement(AppPages.home);
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
