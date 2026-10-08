import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:yoopn/core/dimentions/spacings.dart';

class AuthPageView extends StatelessWidget {
  final String lottiePath;
  final String title;
  final String subtitle;

  const AuthPageView({
    super.key,
    required this.lottiePath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(lottiePath, height: 250.h, width: 250.w),
          Spacing.vertical(10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge!
                .copyWith(fontWeight: FontWeight.w900, fontSize: 20.sp),
            textAlign: TextAlign.center,
          ),
          Spacing.vertical(10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
