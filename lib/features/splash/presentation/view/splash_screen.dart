import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:yoopn/core/resources/app_assets.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SplashBloc, SplashState>(
          listener: (context, state) {
            switch (state.status) {
              case SplashStatus.authenticated:
                context.pushReplacement(AppPages.home);
                break;

              case SplashStatus.unauthenticated:
                context.pushReplacement(AppPages.auth);
                break;

              case SplashStatus.error:
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
