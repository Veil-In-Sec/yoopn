import 'package:flutter/foundation.dart';

class AdConfig {
  AdConfig._();

  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  static const String appId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: testAppId,
  );
  static const String bannerId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: testBannerId,
  );
  static const String rewardedId = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: testRewardedId,
  );

  static bool get isTestMode =>
      kDebugMode || bannerId == testBannerId || appId == testAppId;
}
