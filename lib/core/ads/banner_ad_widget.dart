import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:yoopn/core/ads/ad_config.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Renders one banner slot: either a loaded ad or the reserved-height
/// placeholder. Banner ads are platform-fixed 320x50 **dp** — NOT
/// ScreenUtil-scaled — so the placeholder and the carousel box use the
/// same raw logical height to keep placeholder, loaded ad and page box
/// pixel-identical (mixing `.h` here caused layout jumps / clipping).
class BannerAdView extends StatelessWidget {
  const BannerAdView({super.key, this.ad, this.failed = false});

  final BannerAd? ad;
  final bool failed;

  /// Platform-fixed logical height of [AdSize.banner] (320x50 dp).
  static double get height => AdSize.banner.height.toDouble();

  @override
  Widget build(BuildContext context) {
    final ad = this.ad;
    if (ad != null) {
      return SizedBox(
        width: AdSize.banner.width.toDouble(),
        height: BannerAdView.height,
        child: AdWidget(ad: ad),
      );
    }
    return Container(
      width: double.infinity,
      height: BannerAdView.height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          failed ? 'Ad unavailable' : 'Loading ad…',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.sp, color: AppColors.textHint),
        ),
      ),
    );
  }
}

/// Standalone self-loading banner slot for one-off placements. The carousel
/// (ad_carousel_widget.dart) owns its ads instead so page flips never
/// re-issue load requests.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdConfig.bannerId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AppLogger.i('ADS', 'banner loaded');
          if (mounted) setState(() => _ad = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.w('ADS', 'banner failed: ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
    ad.load().catchError((Object e) {
      AppLogger.w('ADS', 'banner load threw: $e');
      ad.dispose();
      if (mounted) setState(() => _failed = true);
      return null;
    });
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BannerAdView(ad: _ad, failed: _failed);
  }
}
