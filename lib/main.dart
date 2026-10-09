import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/app.dart';
import 'package:yoopn/core/config/supabase_config.dart';
import 'package:yoopn/core/utils/dependency_injection.dart';

void main(List<String> args) async {
  await _init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
        return runApp(
          const ScreenUtilInit(
            designSize: Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: false,
            child: YooPNApp(),
          ),
        );
      });
}

Future<void> _init() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.load();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await init_dependency_injection();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
}
