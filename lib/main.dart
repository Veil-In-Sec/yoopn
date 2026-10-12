import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/app.dart';
import 'package:yoopn/core/ads/ad_config.dart';
import 'package:yoopn/core/ads/rewarded_ad_manager.dart';
import 'package:yoopn/core/config/supabase_config.dart';
import 'package:yoopn/core/telemetry/supabase_telemetry.dart';
import 'package:yoopn/core/utils/app_bloc_observer.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/core/utils/dependency_injection.dart';

bool _isBenign(Object error) {
  if (error is FlutterError && error.toString().contains('overflowed by')) {
    AppLogger.w('UI', 'RenderFlex overflow (not reported as crash)');
    return true;
  }
  final text = error.runtimeType.toString();
  if (text == 'SocketException' ||
      text == 'HttpException' ||
      text == 'HandshakeException' ||
      text == 'TlsException') {
    AppLogger.w('TELEMETRY', 'transient ${error.runtimeType} (not a crash)');
    return true;
  }
  if (error.toString().contains('AuthRetryableFetchException')) {
    AppLogger.w('TELEMETRY', 'Supabase auth refresh retry (not a crash)');
    return true;
  }
  if (error.toString().contains('google_mobile_ads') ||
      (error.runtimeType.toString() == 'MissingPluginException' &&
          error.toString().contains('plugins.flutter.io'))) {
    AppLogger.w('TELEMETRY', 'ads plugin miss (not a crash)');
    return true;
  }
  return false;
}

void main(List<String> args) async {
  Bloc.observer = AppBlocObserver();
  AppLogger.i('APP', 'main() start args=$args');
  FlutterError.onError = (details) {
    final error = details.exception;
    if (_isBenign(error)) return;
    Telemetry.reportCrash(
      error,
      details.stack,
      context: {'library': '${details.library}', 'fatal': true},
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isBenign(error)) return true;
    Telemetry.reportCrash(error, stack, context: {'fatal': true});
    return true;
  };
  await runZonedGuarded(
    () async {
      try {
        await _init();
      } catch (e, st) {
        AppLogger.e('APP', 'init failed - app will still try to run', e, st);
        await Telemetry.reportCrash(e, st, context: {'phase': 'init'});
      }
      Telemetry.init();
      AppLogger.i('APP', 'runApp YooPNApp');
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]).then((_) {
        return runApp(
          const ScreenUtilInit(
            designSize: Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: false,
            child: YooPNApp(),
          ),
        );
      });
    },
    (error, stack) {
      Telemetry.reportCrash(error, stack, context: {'zone': 'root'});
    },
  );
}

Future<void> _init() async {
  AppLogger.d('APP', 'ensureInitialized');
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.d('APP', 'loading .env via SupabaseConfig');
  await SupabaseConfig.load();
  AppLogger.i('APP', 'Supabase.initialize url=${SupabaseConfig.url}');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  AppLogger.i('APP', 'Supabase initialized, session=${Supabase.instance.client.auth.currentSession != null}');
  try {
    await MobileAds.instance.initialize();
    AppLogger.i(
      'ADS',
      AdConfig.isTestMode
          ? 'AdMob ready (TEST ads — pass ADMOB_* dart-defines for release)'
          : 'AdMob ready (production ids)',
    );
  } catch (e) {
    AppLogger.w('ADS', 'AdMob init failed: $e');
  }
  unawaited(RewardedAdManager.instance.preload());
  AppLogger.d('APP', 'initDependencyInjection start');
  await initDependencyInjection();
  AppLogger.i('APP', 'dependency injection done');
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
}
