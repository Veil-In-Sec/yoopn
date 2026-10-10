import 'package:lottie/lottie.dart';
import 'package:yoopn/core/resources/app_assets.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Parses heavy Lottie compositions ahead of first display.
///
/// `AssetLottie.load()` is backed by `sharedLottieCache` (keyed by asset
/// path), so warming here means `Lottie.asset(samePath)` later hits the
/// cache instead of parsing 60–270KB of JSON on the UI thread mid-screen.
/// `backgroundLoading: true` moves the parse into an isolate (`compute`),
/// so the warmup itself never janks either. Fire-and-forget by design.
class LottieWarmup {
  LottieWarmup._();

  static bool _started = false;

  static void warmup() {
    if (_started) return;
    _started = true;
    Future(() async {
      final sw = Stopwatch()..start();
      try {
        await Future.wait([
          AssetLottie(AppAssets.securityAnime, backgroundLoading: true)
              .load(),
          AssetLottie(AppAssets.vpnAnime, backgroundLoading: true).load(),
          AssetLottie(AppAssets.speedAnime, backgroundLoading: true).load(),
          AssetLottie(AppAssets.passwordAnime, backgroundLoading: true)
              .load(),
        ]);
        AppLogger.i('LOTTIE', 'warmup done in ${sw.elapsedMilliseconds}ms');
      } catch (e) {
        AppLogger.w('LOTTIE', 'warmup failed', e);
      }
    });
  }
}
