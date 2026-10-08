import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/app.dart';

void main(List<String> args) async {
  
  await _init();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
}
