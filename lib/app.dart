import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/core/routes/app_routes.dart';
import 'package:yoopn/core/themes/app_theme.dart';
import 'package:yoopn/core/utils/dependency_injection.dart';
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

class YooPNApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SplashBloc>()..add(const AppStarted()))
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        routerConfig: appRouter,
      ),
    );
  }
}