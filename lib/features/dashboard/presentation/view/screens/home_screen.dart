import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/connect_button.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/home_header.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/server_selector.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/status_panel.dart';

/// Home screen, structured like 1.1.1.1: one dominant power button with the
/// status directly above it and the location picker directly below, so the
/// primary action is unmissable. Account details are demoted to a small
/// top row.
///
/// Stateless and never rebuilds by itself — every dynamic part listens to its
/// own slice of `VpnBloc`.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    AppLogger.d('UI', 'HomeScreen build email=${AppLogger.maskEmail(email)}');
    return SafeArea(
      bottom: false,
      child: Padding(
        // Bottom inset clears the floating bottom nav.
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 108.h),
        // Scrolls when the content is taller than the viewport (small phones,
        // large font scale). `IntrinsicHeight` gives the Spacers a definite
        // height to divide, which keeps the button optically centred.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    HomeHeader(email: email),
                    const Spacer(),
                    const StatusPanel(),
                    const Spacer(),
                    const ConnectButton(),
                    const Spacer(),
                    const ServerSelector(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}