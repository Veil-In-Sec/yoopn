import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/resources/app_assets.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/auth/presentation/helper/auth_page_data.dart';


const List<AuthPageData> pages = [
  AuthPageData(
    lottiePath: AppAssets.securityAnime,
    title: "Secure & Protected",
    subtitle:
        "Your information is secured by \nPost Quantum realtime encryption.",
  ),
  AuthPageData(
    lottiePath: AppAssets.vpnAnime,
    title: "Break Borders,\nBrowse Anywhere",
    subtitle:
        "Access blocked content globally, \nany websites, anytime, anywhere.",
  ),
  AuthPageData(
    lottiePath: AppAssets.speedAnime,
    title: "Fast & Stable",
    subtitle: "High speed server worldwide everywhere, \nno drops or waiting.",
  ),
];

void startAutoPlay(Timer? timer, Duration autoPlayInterval, PageController pageController, ValueNotifier<int> currentPage) {
  timer?.cancel();
  timer = Timer.periodic(autoPlayInterval, (_) {
    if (!pageController.hasClients) return;
    final next = (currentPage.value + 1) % pages.length;
    pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  });
}

void showOtpDialog(BuildContext context, String email) {
  AppLogger.i('UI', 'showOtpDialog for ${AppLogger.maskEmail(email)}');
  final otpController = TextEditingController();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Enter Verification Code',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A verification link and 6-digit code were sent to $email.\nClick the link in your email or enter the code below:',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            Spacing.vertical(16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: '123456',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final otp = otpController.text.trim();
              AppLogger.i('UI', 'OTP dialog Verify tapped len=${otp.length}');
              if (otp.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(AuthOtpSubmitted(otp));
              } else {
                AppLogger.w('UI', 'OTP dialog empty — ignored');
              }
            },
            child: const Text('Verify'),
          ),
        ],
      );
    },
  );
}
