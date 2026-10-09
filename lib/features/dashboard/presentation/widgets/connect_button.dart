import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key});

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.55,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  late final Animation<double> _fade = Tween<double>(
    begin: 0.5,
    end: 0,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 150.r;

    return BlocConsumer<VpnBloc, VpnState>(
      // Server changes never touch this widget.
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.errorMessage != curr.errorMessage,
      buildWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
        // Animation is driven here, so no widget rebuilds per frame.
        if (state.status == VpnStatus.disconnected) {
          _pulse
            ..stop()
            ..value = 0;
        } else if (!_pulse.isAnimating) {
          _pulse.repeat();
        }
      },
      builder: (context, state) {
        final connected = state.status == VpnStatus.connected;
        final idle = state.status == VpnStatus.disconnected;

        return RepaintBoundary(
          child: SizedBox(
            width: size * 1.6,
            height: size * 1.6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse ring: Scale/FadeTransition only repaint, never rebuild.
                FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.read<VpnBloc>().add(const VpnToggled());
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: idle
                          ? AppColors.surface
                          : AppColors.primary.withValues(
                              alpha: connected ? 1 : 0.7,
                            ),
                      border: Border.all(
                        color: idle ? AppColors.border : AppColors.primary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: connected ? 0.35 : 0.08,
                          ),
                          blurRadius: connected ? 36 : 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 56.r,
                      color: idle
                          ? AppColors.textSecondary
                          : AppColors.onPrimary,
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
