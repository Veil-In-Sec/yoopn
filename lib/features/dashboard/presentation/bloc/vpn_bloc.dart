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

  /// Hard foreground budget for a refresh: the visible process (spinner)
  /// always settles within this, either with fresh data or with what we
  /// have. A slow fetch keeps running and lands via
  /// [VpnServersBackgroundRefreshed] / [VpnServersBackgroundFailed].
  static const _refreshBudget = Duration(seconds: 2);

  /// Single-flight fetch shared by overlapping requests of the same kind,
  /// so double-taps and screen re-entries never double the traffic.
  Future<List<VpnServer>>? _serversInflight;
  bool _serversInflightForced = false;

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

  /// Adopts a live OS tunnel after an app restart (the VpnService outlives
  /// the Flutter process). Only reconciles an idle UI — never interrupts a
  /// connect/disconnect in flight. Silent on failure: staying disconnected
  /// is the safe default, and no snackbar should greet a cold start.
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
    // Duration counts from the reopen — the true start died with the old
    // process. The server pick can't be recovered either (the engine was
    // given only the country name), so selection stays as-is.
    emit(state.copyWith(status: VpnStatus.connected, connectedSince: DateTime.now()));
  }

  /// Freshest engine sub-stage for telemetry. The failure completer resolves
  /// in a microtask while the matching detail event still sits in the event
  /// queue, so `state.connectionDetail` can lag one stage behind (seen as
  /// `stage: Preparing…` on an `auth_failed` failure). The synchronous read
  /// wins; state is the fallback.
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
    // Only block connect while loading when there is nothing usable to
    // connect to yet (initial boot: `server == ''`, only config-less
    // placeholders). A background force-refresh must NOT block connecting
    // to the already-cached live relays — the patient fetch (30s×5) runs
    // for minutes in the background while the visible budget is 2s.
    // and the user should still be able to dial during that window.
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
    // No live relay available (only built-in placeholders without configs).
    // Kick off a background refresh so the next tap has something to use.
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
    final forced = event.forceRefresh;
    // Join an in-flight fetch of the same kind instead of doubling a
    // multi-megabyte download.
    final Future<List<VpnServer>> pending;
    if (_serversInflight != null && _serversInflightForced == forced) {
      pending = _serversInflight!;
      AppLogger.d('VPN', 'servers request joined in-flight fetch');
    } else {
      _serversInflightForced = forced;
      pending = _serversInflight =
          useCases.getVpnServers(forceRefresh: forced);
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
      _serversInflight = null;
    } on TimeoutException {
      // Budget exceeded: settle the visible process NOW with what we have
      // (spinner stops at ≤2s) and let the same fetch finish in the
      // background — no second download, no lost result.
      AppLogger.w(
        'VPN',
        'refresh exceeded ${_refreshBudget.inSeconds}s — showing current '
        'list, finishing in background',
      );
      unawaited(
        pending.then(
          (fresh) {
            _serversInflight = null;
            if (!isClosed) add(VpnServersBackgroundRefreshed(fresh));
          },
          onError: (Object e) {
            _serversInflight = null;
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
      _serversInflight = null;
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
    await _emitLoadedServers(emit, servers);
  }

  /// Shared selection policy for foreground and background completions.
  Future<void> _emitLoadedServers(
    Emitter<VpnState> emit,
    List<VpnServer> servers,
  ) async {
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
    await _emitLoadedServers(emit, event.servers);
  }

  void _onBackgroundFailed(
    VpnServersBackgroundFailed event,
    Emitter<VpnState> emit,
  ) {
    if (isClosed) return;
    // Only downgrade when there is still nothing usable: with data on
    // screen a background failure is not worth a snackbar.
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
