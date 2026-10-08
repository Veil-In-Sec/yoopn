import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:yoopn/core/resources/app_assets.dart';

class SplashScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Lottie.asset(AppAssets.splashAnimationLogo, repeat: false),
      ),
    );
  }
}