import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/themes/app_colors.dart';

/// Static document page (Terms, Safety, Disclaimer): back button, title,
/// headed sections. Content lives in the const lists below.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              Spacing.vertical(12),
              for (final (heading, body) in sections) ...[
                Text(
                  heading,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                Spacing.vertical(14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const termsSections = <(String, String)>[
  (
    'The service',
    'YooPN provides private VPN connections through volunteer-run relay '
        'servers. Features, speeds, and server availability may change at '
        'any time as relays join or leave the network.',
  ),
  (
    'Acceptable use',
    'Use the service only for lawful purposes. You are responsible for all '
        'activity under your account. Abusing relays (spam, attacks, or '
        'any illegal activity) may lead to suspension.',
  ),
  (
    'Accounts',
    'Keep your login details private. You are responsible for keeping your '
        'account credentials safe and for signing out on shared devices.',
  ),
  (
    'Premium plans',
    'Paid plans, where offered, are billed through the app store. Plan '
        'benefits apply while the subscription is active and may vary by '
        'region.',
  ),
];

const safetySections = <(String, String)>[
  (
    'Stay protected',
    'Keep the VPN connected on public Wi-Fi, and check that the toggle '
        'shows ON before banking, shopping, or logging in anywhere.',
  ),
  (
    'Keep the app updated',
    'Updates carry security fixes and faster, more reliable relays. '
        'Install them as soon as they are available.',
  ),
  (
    'If the tunnel drops',
    'Your traffic is only encrypted while the toggle shows connected. If '
        'a relay stalls, disconnect and pick another server before '
        'continuing anything sensitive.',
  ),
  (
    'Your account',
    'Never share your password or verification codes. YooPN staff will '
        'never ask for them.',
  ),
];

const disclaimerSections = <(String, String)>[
  (
    'As-is service',
    'YooPN is provided "as is", without warranties of any kind. We do not '
        'guarantee uninterrupted, error-free, or high-speed connections.',
  ),
  (
    'Volunteer relays',
    'Connections run over public volunteer relays. Speeds, latency, and '
        'availability depend on those third parties and vary over time.',
  ),
  (
    'No liability',
    'To the maximum extent permitted by law, YooPN and its developers are '
        'not liable for any loss arising from the use of, or inability to '
        'use, the service.',
  ),
];
