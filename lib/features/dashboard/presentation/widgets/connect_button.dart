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

/// The single focal point of the home screen: one large power button, like
/// 1.1.1.1. Outline when idle, filled orange when protected, with a breathing
/// halo while a connection is being established.
class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key});

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 1.22,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  late final Animation<double> _fade = Tween<double>(
    begin: 0.35,
    end: 0.0,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _syncAnimation(VpnStatus status) {
    if (status == VpnStatus.disconnected) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1.1.1.1 uses a dominant circle. Room is reserved for the pulse ring so
    // neighbours never move when it expands.
    final diameter = 210.r;

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
        // Driven here so no widget rebuilds per animation frame.
        _syncAnimation(state.status);
      },
      builder: (context, state) {
        final status = state.status;
        final connected = status == VpnStatus.connected;
        final busy = status == VpnStatus.connecting;

        return RepaintBoundary(
          child: SizedBox(
            width: diameter * 1.35,
            height: diameter * 1.35,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Breathing halo — repaint only.
                FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: diameter,
                      height: diameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: connected ? 'Disconnect VPN' : 'Connect VPN',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppLogger.i('UI', 'ConnectButton tapped → VpnToggled');
                      HapticFeedback.mediumImpact();
                      context.read<VpnBloc>().add(const VpnToggled());
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      width: diameter,
                      height: diameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: connected
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryLight,
                                  AppColors.primary,
                                ],
                              )
                            : null,
                        color: connected ? null : AppColors.surface,
                        border: Border.all(
                          color: connected || busy
                              ? Colors.transparent
                              : AppColors.border,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: connected ? 0.38 : busy ? 0.18 : 0.06,
                            ),
                            blurRadius: connected ? 40 : busy ? 24 : 14,
                            offset: Offset(0, connected ? 14 : 8),
                          ),
                        ],
                      ),
                      child: busy
                          // Determinant progress ring: clearer than the old
                          // static icon while the handshake is in flight.
                          ? SizedBox(
                              width: 54.r,
                              height: 54.r,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: AppColors.primary,
                              ),
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 76.r,
                              color: connected
                                  ? AppColors.onPrimary
                                  : AppColors.primary,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}