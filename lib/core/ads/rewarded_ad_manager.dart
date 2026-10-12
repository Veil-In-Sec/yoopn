import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:yoopn/core/ads/ad_config.dart';
import 'package:yoopn/core/utils/app_logger.dart';

class RewardedAdManager {
  RewardedAdManager._();

  static final RewardedAdManager instance = RewardedAdManager._();

  RewardedAd? _ad;
  bool _loading = false;

  bool get isReady => _ad != null;

  Future<void> preload() async {
    if (_ad != null || _loading) return;
    _loading = true;
    try {
      await RewardedAd.load(
        adUnitId: AdConfig.rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            AppLogger.i('ADS', 'rewarded video preloaded');
            _ad = ad;
            _loading = false;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                unawaited(preload());
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                AppLogger.w('ADS', 'rewarded show failed: $error');
                ad.dispose();
                unawaited(preload());
              },
            );
          },
          onAdFailedToLoad: (error) {
            AppLogger.w('ADS', 'rewarded preload failed: $error');
            _loading = false;
          },
        ),
      );
    } catch (e) {
      AppLogger.w('ADS', 'rewarded preload threw: $e');
      _loading = false;
    }
  }

  Future<void> show() async {
    final ad = _ad;
    _ad = null;
    if (ad == null) {
      unawaited(preload());
      return;
    }
    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          AppLogger.i(
            'ADS',
            'reward earned: ${reward.amount} ${reward.type}',
          );
        },
      );
    } catch (e) {
      AppLogger.w('ADS', 'rewarded show threw: $e');
      ad.dispose();
    }
    unawaited(preload());
  }
}
