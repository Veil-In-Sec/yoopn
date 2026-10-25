import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:yoopn/core/ads/ad_config.dart';
import 'package:yoopn/core/ads/banner_ad_widget.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Auto-advancing carousel of banner ads.
///
/// The [BannerAd] objects are owned and cached by this widget's state, so
/// flipping pages never creates a fresh ad + load request (previously every
/// PageView page built its own self-loading ad, re-requesting on each flip).
/// The slide timer also parks itself while this route is covered by another.
class AdCarouselWidget extends StatefulWidget {
  const AdCarouselWidget({
    super.key,
    this.itemCount = 3,
    this.interval = const Duration(seconds: 8),
  });

  final int itemCount;
  final Duration interval;

  @override
  State<AdCarouselWidget> createState() => _AdCarouselWidgetState();
}

class _AdCarouselWidgetState extends State<AdCarouselWidget> {
  ModalRoute<dynamic>? _route;
  late final PageController _pages = PageController();
  Timer? _timer;

  /// Indexed exactly [0 .. itemCount-1]; filled in by the loaders.
  late final List<BannerAd?> _ads;
  late final List<bool> _failed;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _ads = List.filled(widget.itemCount, null);
    _failed = List.filled(widget.itemCount, false);
    for (var i = 0; i < widget.itemCount; i++) {
      _load(i);
    }
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_pages.hasClients || widget.itemCount < 2) return;
      // Covered by a pushed route (servers/profile/menu): stay parked so
      // invisible carousels stop animating.
      if (!(_route?.isCurrent ?? true)) return;
      final current = (_pages.page ?? 0).round();
      _pages.animateToPage(
        (current + 1) % widget.itemCount,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  void _load(int index) {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdConfig.bannerId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AppLogger.i('ADS', 'banner loaded (slot $index)');
          if (_disposed) {
            ad.dispose();
            return;
          }
          setState(() => _ads[index] = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.w('ADS', 'banner failed: ${error.message}');
          ad.dispose();
          if (_disposed) return;
          setState(() => _failed[index] = true);
        },
      ),
    );
    ad.load().catchError((Object e) {
      AppLogger.w('ADS', 'banner load threw: $e');
      ad.dispose();
      if (!_disposed) setState(() => _failed[index] = true);
      return null;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pages.dispose();
    for (final ad in _ads) {
      ad?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Platform-fixed banner height — matches the loaded ad / placeholder.
      height: BannerAdView.height,
      child: PageView.builder(
        controller: _pages,
        itemCount: widget.itemCount,
        itemBuilder: (_, index) =>
            BannerAdView(ad: _ads[index], failed: _failed[index]),
      ),
    );
  }
}
