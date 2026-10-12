import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/ads/banner_ad_widget.dart';

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
  late final PageController _pages = PageController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_pages.hasClients || widget.itemCount < 2) return;
      final current = (_pages.page ?? 0).round();
      _pages.animateToPage(
        (current + 1) % widget.itemCount,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50.h,
      child: PageView.builder(
        controller: _pages,
        itemCount: widget.itemCount,
        itemBuilder: (_, _) => const BannerAdWidget(),
      ),
    );
  }
}
