import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:yoopn/core/ads/ad_config.dart';
import 'package:yoopn/core/utils/app_logger.dart';

class RewardedAdManager {
  RewardedAdManager._();

  static final RewardedAdManager instance = RewardedAdManager._();

  static const int _maxRetryAttempts = 3;

  RewardedAd? _ad;
  bool _loading = false;
  Timer? _retryTimer;
  int _failures = 0;

  /// Open while a rewarded video is on screen; completes the moment its
  /// lifecycle ends (dismissed / failed to show). The ad gate awaits this,
  /// so the user's action resumes as soon as the video is over — there is
  /// no separate countdown (owner decision #9).
  Completer<void>? _flight;

  bool get isReady => _ad != null;

  Future<void> preload() async {
    if (_ad != null || _loading) return;
    _retryTimer?.cancel();
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
            _failures = 0;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                AppLogger.i('ADS', 'rewarded video finished');
                _settleFlight();
                ad.dispose();
                unawaited(preload());
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                AppLogger.w('ADS', 'rewarded show failed: $error');
                _settleFlight();
                ad.dispose();
                unawaited(preload());
              },
            );
          },
          onAdFailedToLoad: (error) {
            AppLogger.w('ADS', 'rewarded preload failed: $error');
            _loading = false;
            _schedulePreloadRetry();
          },
        ),
      );
    } catch (e) {
      AppLogger.w('ADS', 'rewarded preload threw: $e');
      _loading = false;
      _schedulePreloadRetry();
    }
  }

  /// Previously a single preload failure killed rewarded ads for the whole
  /// session (nothing reloaded the next time the gate opened). Retry with a
  /// growing backoff, bounded so a persistent failure stops burning
  /// requests; `show()` always kicks a fresh preload as a last resort.
  void _schedulePreloadRetry() {
    _retryTimer?.cancel();
    if (_ad != null || _loading) return;
    if (_failures >= _maxRetryAttempts) return;
    _failures++;
    final delay = Duration(seconds: 15 * _failures);
    _retryTimer = Timer(delay, () {
      unawaited(preload());
    });
  }

  /// Shows the preloaded rewarded video; the returned future completes
  /// exactly when the video finishes (or instantly when nothing loaded —
  /// no fill means nothing to watch, so the action proceeds at once).
  /// Concurrent callers join the same flight.
  Future<void> show() {
    final existing = _flight;
    if (existing != null) return existing.future;
    final ad = _ad;
    _ad = null;
    if (ad == null) {
      // Nothing preloaded: no video → nothing to wait for.
      unawaited(preload());
      return Future.value();
    }
    final flight = Completer<void>();
    _flight = flight;
    final shown = ad.show(
      onUserEarnedReward: (ad, reward) {
        AppLogger.i('ADS', 'reward earned: ${reward.amount} ${reward.type}');
      },
    );
    // Guard in case rendering fails without invoking the fullscreen
    // callback; the normal path settles from onAdDismissed/FailedToShow.
    unawaited(shown.catchError((Object e) {
      AppLogger.w('ADS', 'rewarded show threw: $e');
      _settleFlight();
      ad.dispose();
      unawaited(preload());
    }));
    return flight.future;
  }

  /// Ends the flight opened by [show] (no-op when none is open).
  void _settleFlight() {
    final flight = _flight;
    _flight = null;
    if (flight != null && !flight.isCompleted) flight.complete();
  }
}
