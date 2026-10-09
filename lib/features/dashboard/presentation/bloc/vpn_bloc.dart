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
    // Live engine sub-stages (Authenticating… / Assigning IP…) keep the
    // "Connecting…" UI truthful on slow relays.
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

  /// Guards against a second connect() while the native engine is still
  /// handshaking from an earlier attempt (which spawns a duplicate
  /// OpenVPN process and orphans the first tunnel).
  bool _connectInFlight = false;

  /// True once the user picks a server by hand. Until then the bloc keeps
  /// re-selecting the best live relay so the power button always works
  /// without opening the server list first.
  bool _userPickedServer = false;

  @override
  Future<void> close() {
    _detailSub?.cancel();
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

  Future<void> _onToggled(VpnToggled event, Emitter<VpnState> emit) async {
    AppLogger.i('VPN', 'VpnToggled tapped (status=${state.status} server=${state.server})');
    switch (state.status) {
      case VpnStatus.connecting:
        // Tapping the power button while connecting cancels the attempt
        // instead of leaving the user trapped on "Connecting…".
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
        'stage': state.connectionDetail,
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

  /// Highest score, then lowest ping, restricted to relays that carry a
  /// usable OpenVPN config.
  ///
  /// Scans the freshly fetched list rather than trusting the repository's
  /// `getBestServer()`: that reads the offline cache first and can return a
  /// config-less fallback entry, which then fails with bad-config.
  static VpnServer? _bestUsableRelay(List<VpnServer> servers) {
    final usable = servers.where((s) => s.isVpnGate).toList()
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        if (score != 0) return score;
        final ap = a.ping < 0 ? 1 << 30 : a.ping;
        final bp = b.ping < 0 ? 1 << 30 : b.ping;
        return ap.compareTo(bp);
      });
    return usable.isEmpty ? null : usable.first;
  }

  void _onServerSelected(VpnServerSelected event, Emitter<VpnState> emit) {
    AppLogger.i('VPN', 'server selected ${event.server} (status=${state.status})');
    // Server can only change while disconnected.
    if (state.status != VpnStatus.disconnected) {
      AppLogger.w('VPN', 'server change blocked — must disconnect first');
      return;
    }
    final server = useCases.selectVpnServer(event.server);
    if (server != null) {
      _userPickedServer = true;
      AppLogger.d('VPN', 'manual selection → ${server.id}');
      emit(state.copyWith(server: server.id));
    }
  }

  Future<void> _onServersRequested(
    VpnServersRequested event,
    Emitter<VpnState> emit,
  ) async {
    AppLogger.i('VPN', 'servers requested force=${event.forceRefresh}');
    if (state.serversStatus == VpnServersStatus.loading) {
      AppLogger.d('VPN', 'servers request deduped — already loading');
      return;
    }
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
      AppLogger.i('VPN', 'servers loaded: ${servers.length} (keep=${state.server})');
      if (isClosed) return;
      // Selection policy:
      //  - user picked a server → keep it (unless it vanished from the list,
      //    then fall back to the best relay in the same country).
      //  - user has not picked → always auto-select the best relay that
      //    actually has an OpenVPN config, so pressing connect works
      //    immediately. The previous default ('United States') is a
      //    config-less fallback entry and always failed with bad-config.
      var selectedId = state.server;
      if (!_userPickedServer) {
        final best = _bestUsableRelay(servers);
        if (best != null) {
          selectedId = best.id;
          AppLogger.i('VPN', 'auto-selected default relay ${best.id} '
              '(score=${best.score} ping=${best.ping})');
        } else {
          AppLogger.w('VPN', 'no connectable relay in ${servers.length} entries');
        }
      } else {
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
      }
      // Never leave an empty selection: connect() would resolve nothing.
      if (selectedId.isEmpty) {
        final best = _bestUsableRelay(servers);
        if (best != null) selectedId = best.id;
      }
      emit(
        state.copyWith(
          servers: servers,
          serversStatus: VpnServersStatus.loaded,
          server: selectedId,
        ),
      );
    } catch (error, st) {
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
    }
  }
}
