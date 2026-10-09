import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/features/dashboard/domain/usecases/dashboard_use_cases.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

class VpnBloc extends Bloc<VpnEvent, VpnState> {
  VpnBloc({required this.useCases}) : super(const VpnState()) {
    on<VpnToggled>(_onToggled);
    on<VpnServerSelected>(_onServerSelected);
  }

  final DashboardUseCases useCases;

  Future<void> _onToggled(VpnToggled event, Emitter<VpnState> emit) async {
    switch (state.status) {
      case VpnStatus.connecting:
        return; // ignore taps while a connection is in progress
      case VpnStatus.connected:
        try {
          await useCases.disconnectVpn();
          if (!isClosed) emit(state.copyWith(status: VpnStatus.disconnected));
        } catch (error) {
          if (!isClosed) {
            emit(state.copyWith(errorMessage: error.toString()));
          }
        }
        return;
      case VpnStatus.disconnected:
        break;
    }

    emit(state.copyWith(status: VpnStatus.connecting));
    try {
      final server = useCases.selectVpnServer(state.server);
      if (server == null) {
        throw StateError('Selected VPN server is unavailable');
      }
      await useCases.connectVpn(server);

      if (isClosed || state.status != VpnStatus.connecting) return;
      emit(state.copyWith(status: VpnStatus.connected));
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: VpnStatus.disconnected,
            errorMessage: error.toString(),
          ),
        );
      }
    }
  }

  void _onServerSelected(VpnServerSelected event, Emitter<VpnState> emit) {
    // Server can only change while disconnected.
    if (state.status != VpnStatus.disconnected) return;
    final server = useCases.selectVpnServer(event.server);
    if (server != null) emit(state.copyWith(server: server.name));
  }
}
