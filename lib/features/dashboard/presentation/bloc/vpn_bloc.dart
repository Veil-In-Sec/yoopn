import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/core/telemetry/supabase_telemetry.dart';
import 'package:yoopn/core/utils/app_logger.dart';
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
    on<VpnConnectionDetailChanged>(_onDetailChanged);
    on<VpnTunnelSyncRequested>(_onTunnelSync);
    on<VpnServersBackgroundRefreshed>(_onBackgroundRefreshed);
    on<VpnServersBackgroundFailed>(_onBackgroundFailed);
    _detailSub = useCases.watchConnectionDetail().listen(
      (detail) {
        if (!isClosed) add(VpnConnectionDetailChanged(detail));
      },
      onError: (Object e) =>
          AppLogger.w('VPN', 'detail stream error: $e'),
    );
  }

  final DashboardUseCases useCases;
  StreamSubscription<String>? _detailSub;

  bool _connectInFlight = false;

  static const _refreshBudget = Duration(seconds: 2);

  Future<List<VpnServer>>? _serversInflight;
  Future<List<VpnServer>>? _serversInflightForced;

  @override
  Future<void> close() async {
    await _detailSub?.cancel();
    _serversInflight = null;
    _serversInflightForced = null;
    return super.close();
  }

  void _onDetailChanged(
    VpnConnectionDetailChanged event,
    Emitter<VpnState> emit,
  ) {
    if (state.status != VpnStatus.connecting) return;
    if (event.detail == state.connectionDetail) return;
    emit(state.copyWith(connectionDetail: event.detail));
  }

  Future<void> _onTunnelSync(
    VpnTunnelSyncRequested event,
    Emitter<VpnState> emit,
  ) async {
    if (state.status != VpnStatus.disconnected) return;
    AppLogger.i('VPN', 'tunnel sync requested');
    bool connected;
    try {
      connected = await useCases.syncTunnelState();
    } catch (e) {
      AppLogger.w('VPN', 'tunnel sync failed, staying disconnected', e);
      return;
    }
    if (!connected || isClosed || state.status != VpnStatus.disconnected) {
      return;
    }
    AppLogger.i('VPN', 'adopted live tunnel (connected before restart)');
    emit(state.copyWith(status: VpnStatus.connected, connectedSince: DateTime.now()));
  }

  String _liveStage() {
    try {
      final live = useCases.watchConnectionDetail.lastDetail();
      if (live.isNotEmpty) return live;
    } catch (_) {}
    return state.connectionDetail;
  }

  Future<void> _onToggled(VpnToggled event, Emitter<VpnState> emit) async {
    AppLogger.i('VPN', 'VpnToggled tapped (status=${state.status} server=${state.server})');
    switch (state.status) {
      case VpnStatus.connecting:
        AppLogger.i('VPN', 'cancelling in-flight connect…');
        _connectInFlight = false;
        Telemetry.track('vpn_cancelled', {'server': state.server});
        try {
          await useCases.disconnectVpn();
        } catch (error, st) {
          AppLogger.w('VPN', 'cancel disconnect threw: $error $st');
        }
        if (!isClosed) emit(state.copyWith(status: VpnStatus.disconnected));
        return;
      case VpnStatus.connected:
        AppLogger.i('VPN', 'disconnecting…');
        Telemetry.track('vpn_disconnect', {'server': state.server});
        try {
          await useCases.disconnectVpn();
          AppLogger.i('VPN', 'disconnected');
          if (!isClosed) {
            emit(state.copyWith(status: VpnStatus.disconnected));
          }
        } catch (error, st) {
          AppLogger.e('VPN', 'disconnect failed', error, st);
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

    if (_connectInFlight) {
      AppLogger.d('VPN', 'connect ignored — tunnel already handshaking');
      return;
    }
    final hasUsableRelay = state.servers.any((s) => s.isVpnGate);
    if (state.serversStatus == VpnServersStatus.loading && !hasUsableRelay) {
      AppLogger.w('VPN', 'connect blocked — initial list still loading');
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage:
                'Loading servers… wait for the list to finish, then try again.',
          ),
        );
      }
      return;
    }
    if (!hasUsableRelay) {
      AppLogger.w(
        'VPN',
        'connect blocked — no live relay in ${state.servers.length} entries',
      );
      if (!isClosed) {
        add(const VpnServersRequested(forceRefresh: true));
        emit(
          state.copyWith(
            errorMessage:
                'No live servers yet. Refreshing… open Location, pick a relay showing host/IP, then connect.',
          ),
        );
      }
      return;
    }
    if (state.server.isEmpty) {
      // Owner decision #10: nothing is auto-selected — connecting requires
      // an explicit server pick. The connect button routes to the servers
      // screen before reaching here; this is the guard for other callers.
      AppLogger.w('VPN', 'connect blocked — no server selected yet');
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage:
                'Select a server first. Open Location, pick a relay showing host/IP, then connect.',
          ),
        );
      }
      return;
    }
    _connectInFlight = true;
    final startedAt = DateTime.now();
    AppLogger.i('VPN', 'connecting to ${state.server}…');
    Telemetry.track('vpn_connect_started', {'server': state.server});
    emit(
      state.copyWith(
        status: VpnStatus.connecting,
        connectionDetail: 'Preparing…',
        connectStartedAt: startedAt,
      ),
    );
    try {
      final server = useCases.selectVpnServer(state.server);
      AppLogger.d('VPN', 'resolved server → ${server?.id ?? 'null'}');
      if (server == null) {
        throw const VpnException(
          'no-server',
          'Selected VPN server is unavailable. Refresh the list.',
        );
      }
      if (!server.isVpnGate) {
        throw VpnException(
          'bad-config',
          '“${server.name}” is a built-in placeholder with no VPN config. Open Location, refresh, and pick a live relay showing host/IP.',
        );
      }
      await useCases.connectVpn(server);
      AppLogger.i('VPN', 'tunnel connect ok → connected');

      if (isClosed || state.status != VpnStatus.connecting) {
        AppLogger.w('VPN', 'state changed mid-connect, abort emit');
        _connectInFlight = false;
        return;
      }
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      Telemetry.track('vpn_connected', {
        'server': server.id,
        'elapsed_s': elapsed,
      });
      _connectInFlight = false;
      emit(
        state.copyWith(
          status: VpnStatus.connected,
          connectedSince: DateTime.now(),
        ),
      );
    } catch (error, st) {
      _connectInFlight = false;
      if (error is VpnException && error.code == 'cancelled') {
        AppLogger.i('VPN', 'connect cancelled by user');
        if (!isClosed) emit(state.copyWith(status: VpnStatus.disconnected));
        return;
      }
      AppLogger.e('VPN', 'connect failed', error, st);
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      Telemetry.track('vpn_connect_failed', {
        'server': state.server,
        'error': error.toString(),
        'stage': _liveStage(),
        'elapsed_s': elapsed,
      });
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
    AppLogger.i('VPN', 'server selected ${event.server} (status=${state.status})');
    if (state.status != VpnStatus.disconnected) {
      AppLogger.w('VPN', 'server change blocked — must disconnect first');
      return;
    }
    final server = useCases.selectVpnServer(event.server);
    if (server != null) {
      AppLogger.d('VPN', 'manual selection → ${server.id}');
      emit(state.copyWith(server: server.id));
    }
  }

  Future<void> _onServersRequested(
    VpnServersRequested event,
    Emitter<VpnState> emit,
  ) async {
    AppLogger.i('VPN', 'servers requested force=${event.forceRefresh}');
    final forced = event.forceRefresh;
    final Future<List<VpnServer>> pending;
    if (forced) {
      pending = _serversInflightForced ??=
          useCases.getVpnServers(forceRefresh: true);
    } else {
      pending = _serversInflight ??= useCases.getVpnServers();
    }
    if (state.serversStatus != VpnServersStatus.loading) {
      emit(
        state.copyWith(
          serversStatus: VpnServersStatus.loading,
          servers: state.servers,
        ),
      );
    }
    final List<VpnServer> servers;
    try {
      servers = await pending.timeout(_refreshBudget);
      if (forced) {
        _serversInflightForced = null;
      } else {
        _serversInflight = null;
      }
    } on TimeoutException {
      AppLogger.w(
        'VPN',
        'refresh exceeded ${_refreshBudget.inSeconds}s — showing current '
        'list, finishing in background',
      );
      unawaited(
        pending.then(
          (fresh) {
            if (forced) {
              _serversInflightForced = null;
            } else {
              _serversInflight = null;
            }
            if (!isClosed) add(VpnServersBackgroundRefreshed(fresh));
          },
          onError: (Object e) {
            if (forced) {
              _serversInflightForced = null;
            } else {
              _serversInflight = null;
            }
            if (!isClosed) add(VpnServersBackgroundFailed(e));
          },
        ),
      );
      if (isClosed) return;
      final hasUsable = state.servers.any((s) => s.isVpnGate);
      emit(
        state.copyWith(
          servers: state.servers,
          serversStatus:
              hasUsable ? VpnServersStatus.loaded : VpnServersStatus.failure,
          serversError: hasUsable
              ? null
              : 'Still loading — taking longer than 2 seconds. The list will update automatically.',
        ),
      );
      return;
    } catch (error, st) {
      if (forced) {
        _serversInflightForced = null;
      } else {
        _serversInflight = null;
      }
      AppLogger.e('VPN', 'servers load failed', error, st);
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
      return;
    }
    if (isClosed) return;
    AppLogger.i('VPN', 'servers loaded: ${servers.length} (keep=${state.server})');
    _emitLoadedServers(emit, servers);
  }

  void _emitLoadedServers(
    Emitter<VpnState> emit,
    List<VpnServer> servers,
  ) {
    // Owner decision #10: no server is ever selected on the app's behalf.
    // The user's explicit pick survives refreshes; when the picked relay
    // has vanished from the fresh list the selection CLEARS (no silent
    // re-pick), so the next connect forces a fresh, deliberate choice.
    var selectedId = state.server;
    if (selectedId.isNotEmpty &&
        !servers.any((s) => s.matchesId(selectedId))) {
      AppLogger.w(
        'VPN',
        'picked relay vanished ($selectedId) — clearing selection',
      );
      selectedId = '';
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        servers: servers,
        serversStatus: VpnServersStatus.loaded,
        // Never move the selection while a tunnel is up or handshaking:
        // connect() shook hands with the server chosen at tap time.
        server:
            state.status == VpnStatus.disconnected ? selectedId : state.server,
      ),
    );
  }

  Future<void> _onBackgroundRefreshed(
    VpnServersBackgroundRefreshed event,
    Emitter<VpnState> emit,
  ) async {
    if (isClosed) return;
    AppLogger.i(
      'VPN',
      'background refresh landed (${event.servers.length} servers)',
    );
    _emitLoadedServers(emit, event.servers);
  }

  void _onBackgroundFailed(
    VpnServersBackgroundFailed event,
    Emitter<VpnState> emit,
  ) {
    if (isClosed) return;
    final hasUsable = state.servers.any((s) => s.isVpnGate);
    if (hasUsable) {
      AppLogger.w('VPN', 'background refresh failed, keeping current list');
      return;
    }
    AppLogger.w('VPN', 'background refresh failed with nothing to show');
    emit(
      state.copyWith(
        serversStatus: VpnServersStatus.failure,
        serversError: VpnFailure.from(event.error).message,
        servers: state.servers,
      ),
    );
  }
}
