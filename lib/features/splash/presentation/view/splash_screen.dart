import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:yoopn/core/resources/app_assets.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

class SplashScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashBloc, SplashState>(
      listener: (context, state) {
        switch (state.status) {
          case SplashStatus.loaded:
            context.pushReplacement(AppPages.home);
            break;

          case SplashStatus.error:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMsg ?? 'Something went wrong'),
                action: SnackBarAction(
                  label: "Retry",
                  onPressed: () =>
                      context.read<SplashBloc>()..add(AppStarted()),
                ),
              ),
            );
            break;

          case SplashStatus.loading:
            break;
        }
      },
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
