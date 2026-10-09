import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/domain/usecases/dashboard_use_cases.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

class VpnBloc extends Bloc<VpnEvent, VpnState> {
  VpnBloc({required this.useCases}) : super(const VpnState()) {
    on<VpnToggled>(_onToggled);
    on<VpnServerSelected>(_onServerSelected);
    on<VpnServersRequested>(_onServersRequested);
  }

  final DashboardUseCases useCases;

  Future<void> _onToggled(VpnToggled event, Emitter<VpnState> emit) async {
    switch (state.status) {
      case VpnStatus.connecting:
        return; // ignore taps while a connection is in progress
      case VpnStatus.connected:
        try {
          await useCases.disconnectVpn();
          if (!isClosed) {
            emit(state.copyWith(status: VpnStatus.disconnected));
          }
        } catch (error) {
          if (!isClosed) {
            emit(
              state.copyWith(errorMessage: VpnFailure.from(error).message),
            );
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
        throw const VpnException(
          'no-server',
          'Selected VPN server is unavailable. Refresh the list.',
        );
      }
      await useCases.connectVpn(server);

      if (isClosed || state.status != VpnStatus.connecting) return;
      emit(
        state.copyWith(
          status: VpnStatus.connected,
          connectedSince: DateTime.now(),
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: VpnStatus.disconnected,
            errorMessage: VpnFailure.from(error).message,
          ),
        );
      }
    }
  }

  void _onServerSelected(VpnServerSelected event, Emitter<VpnState> emit) {
    // Server can only change while disconnected.
    if (state.status != VpnStatus.disconnected) return;
    final server = useCases.selectVpnServer(event.server);
    if (server != null) emit(state.copyWith(server: server.id));
  }

  Future<void> _onServersRequested(
    VpnServersRequested event,
    Emitter<VpnState> emit,
  ) async {
    if (state.serversStatus == VpnServersStatus.loading) return;
    emit(
      state.copyWith(
        serversStatus: VpnServersStatus.loading,
        servers: state.servers,
      ),
    );
    try {
      final servers = await useCases.getVpnServers(
        forceRefresh: event.forceRefresh,
      );
      if (isClosed) return;
      // Keep the current selection when still available; otherwise fall
      // back to the best relay (score/ping) so connect never points nowhere.
      var selectedId = state.server;
      final stillAvailable = servers.any((s) => s.matchesId(selectedId));
      if (!stillAvailable && servers.isNotEmpty) {
        final previous = useCases.selectVpnServer(selectedId);
        VpnServer? sameCountry;
        if (previous != null) {
          for (final s in servers) {
            if (s.name == previous.name) {
              sameCountry = s;
              break;
            }
          }
        }
        selectedId =
            sameCountry?.id ?? (await useCases.getBestServer())?.id ??
            servers.first.id;
      }
      emit(
        state.copyWith(
          servers: servers,
          serversStatus: VpnServersStatus.loaded,
          server: selectedId,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          serversStatus: VpnServersStatus.failure,
          serversError: VpnFailure.from(error).message,
          servers: state.servers.isEmpty
              ? VpnServer.availableServers
              : state.servers,
        ),
      );
    }
  }
}
