import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/core/routes/app_routes.dart';
import 'package:yoopn/core/themes/app_theme.dart';
import 'package:yoopn/core/utils/dependency_injection.dart';
<<<<<<< HEAD
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
=======
>>>>>>> 5a5552a99aee2e3f776e5e720b49ebac3b94f5ab
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

class YooPNApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
<<<<<<< HEAD
        BlocProvider(create: (_) => sl<SplashBloc>()..add(const AppStarted())),
        BlocProvider(create: (_) => sl<AuthBloc>()),
=======
        BlocProvider(create: (_) => sl<SplashBloc>()..add(const AppStarted()))
>>>>>>> 5a5552a99aee2e3f776e5e720b49ebac3b94f5ab
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