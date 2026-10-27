import 'package:yoopn/core/ads/rewarded_ad_manager.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Rewarded-video gate: the caller `await`s [startAdGate] and proceeds the
/// moment the video finishes (owner decision #9 — the video itself is the
/// wait; the old 30s countdown pop-up is gone). When no video is available
/// (no fill) the gate resolves immediately.
///
/// Concurrent callers JOIN the in-flight gate instead of starting a second
/// video; connects, disconnects and ad-gated server changes all funnel
/// through here.
Future<void>? _gateFlight;

Future<void> startAdGate() {
  final flight = _gateFlight;
  if (flight != null) return flight;
  final future = RewardedAdManager.instance
      .show()
      .timeout(const Duration(milliseconds: 1800), onTimeout: () {
    AppLogger.w('ADS', 'ad gate timed out — proceeding without ad');
  });
  _gateFlight = future;
  future.whenComplete(() {
    if (identical(_gateFlight, future)) _gateFlight = null;
  });
  return future;
}
