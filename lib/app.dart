import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:yoopn/core/routes/app_routes.dart';
import 'package:yoopn/core/themes/app_theme.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/core/utils/dependency_injection.dart';
import 'package:yoopn/core/ads/ad_counter_store.dart';
import 'package:yoopn/core/utils/notification_permission.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

class YooPNApp extends StatefulWidget {
  const YooPNApp({super.key});

  @override
  State<YooPNApp> createState() => _YooPNAppState();
}

class _YooPNAppState extends State<YooPNApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationPermission.ensureGranted();
    });
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.d('APP', 'YooPNApp build → providing Splash/Auth/Vpn blocs');
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SplashBloc>()..add(const AppStarted())),
        BlocProvider(create: (_) => sl<AuthBloc>()),
        BlocProvider(create: (_) => sl<VpnBloc>()),
        Provider<AdCounterStore>(create: (_) => sl<AdCounterStore>()),
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
