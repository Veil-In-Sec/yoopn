import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/connect_button.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/home_header.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/server_selector.dart';
import 'package:yoopn/features/dashboard/presentation/widgets/status_panel.dart';

/// Stateless and never rebuilds by itself: every dynamic part below
/// listens to its own small slice of state from VpnBloc.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Bottom padding leaves room for the floating bottom nav.
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 110.h),
        child: Column(
          children: [
            HomeHeader(email: email),
            const Spacer(),
            const StatusPanel(),
            SizedBox(height: 32.h),
            const ConnectButton(),
            const Spacer(),
            const ServerSelector(),
          ],
        ),
      ),
    );
  }
}