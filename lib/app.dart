import 'package:flutter/material.dart';
import 'package:yoopn/core/themes/app_theme.dart';
import 'package:yoopn/features/splash/presentation/view/splash_screen.dart';

class YooPNApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: SplashScreen(),
    );
  }
}