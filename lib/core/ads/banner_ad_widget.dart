import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:yoopn/core/ads/ad_config.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';

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
    const height = 50.0;
    final ad = _ad;
    if (ad != null) {
      return SizedBox(
        width: AdSize.banner.width.toDouble(),
        height: height,
        child: AdWidget(ad: ad),
      );
    }
    return Container(
      width: double.infinity,
      height: height.h,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          _failed ? 'Ad unavailable' : 'Loading ad…',
          style: TextStyle(fontSize: 10.sp, color: AppColors.textHint),
        ),
      ),
    );
  }
}
