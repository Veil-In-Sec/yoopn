import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

/// The single focal point of the home screen: a neon on/off toggle switch.
/// Thumb left = standby, thumb right = protected. Same tap, haptics and
/// semantics contract as before — only the visuals changed.
class ConnectButton extends StatelessWidget {
  const ConnectButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VpnBloc, VpnState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.errorMessage != curr.errorMessage,
      buildWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        AppLogger.i(
          'UI',
          'ConnectButton status=${state.status} err=${state.errorMessage}',
        );
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      builder: (context, state) {
        final status = state.status;
        final connected = status == VpnStatus.connected;
        final busy = status == VpnStatus.connecting;

        return RepaintBoundary(
          child: Semantics(
            button: true,
            toggled: connected,
            label: connected ? 'Disconnect VPN' : 'Connect VPN',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                AppLogger.i('UI', 'ConnectButton tapped → VpnToggled');
                HapticFeedback.mediumImpact();
                context.read<VpnBloc>().add(const VpnToggled());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: 160.w,
                height: 58.h,
                padding: EdgeInsets.symmetric(horizontal: 5.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34.r),
                  gradient: connected
                      ? const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.primaryLight,
                            AppColors.primary,
                          ],
                        )
                      : null,
                  color: connected ? null : AppColors.surface,
                  // Neon outline only — no outer glow.
                  border: Border.all(
                    color: connected
                        ? AppColors.onPrimary.withValues(alpha: 0.9)
                        : AppColors.primary,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // ON/OFF captions under the sliding thumb.
                    Positioned.fill(
                      child: Row(
                        children: [
                          SizedBox(width: 12.w),
                          Text(
                            'OFF',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              color: connected
                                  ? AppColors.onPrimary
                                      .withValues(alpha: 0.65)
                                  : AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'ON',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              color: connected
                                  ? AppColors.onPrimary
                                  : AppColors.textHint,
                            ),
                          ),
                          SizedBox(width: 12.w),
                        ],
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: connected
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 48.h,
                        height: 48.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: connected
                              ? AppColors.onPrimary
                              : AppColors.surface,
                          border: connected
                              ? null
                              : Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: busy ? 0.7 : 0.45,
                                  ),
                                  width: 1.5,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: connected ? 0.22 : 0.1,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: busy
                            ? Center(
                                child: SizedBox(
                                  width: 20.r,
                                  height: 20.r,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: connected
                                        ? AppColors.onPrimary
                                        : AppColors.primary,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.power_settings_new_rounded,
                                size: 24.r,
                                color: connected
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.75),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
