import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import '../../domain/entities/vpn_server.dart';
import '../../domain/repositories/vpn_repository.dart';
import '../datasources/vpn_data_source.dart';
import '../datasources/vpn_gate_remote_data_source.dart';
import '../datasources/vpn_local_data_source.dart';
import '../models/vpn_server_model.dart';

class VpnRepositoryImpl implements VpnRepository {
  VpnRepositoryImpl({
    required this.connectionDataSource,
    required this.gateDataSource,
    required this.localDataSource,
  });

  final VpnDataSource connectionDataSource;
  final VpnGateRemoteDataSource gateDataSource;
  final VpnLocalDataSource localDataSource;

  /// Last known good list. Starts as the static fallback.
  List<VpnServer> _servers = VpnServer.availableServers;

  /// Bundled snapshot, parsed once on first need.
  List<VpnServer>? _snapshot;

  List<VpnServer> get cachedServers => List.unmodifiable(_servers);

  @override
  Future<void> connect(VpnServer server) {
    AppLogger.i('VPN', 'repo.connect ${server.id}');
    final availableServer = findServer(server.id);
    if (availableServer == null) {
      throw ArgumentError.value(server.id, 'server', 'Unknown VPN server');
    }
    return connectionDataSource.connect(availableServer);
  }

  @override
  Future<void> disconnect() {
    AppLogger.i('VPN', 'repo.disconnect');
    return connectionDataSource.disconnect();
  }

  @override
  VpnServer? findServer(String name) {
    if (name.isEmpty) return null;
    for (final server in _servers) {
      if (server.matchesId(name)) return server;
    }
    for (final server in VpnServer.availableServers) {
      if (server.matchesId(name)) return server;
    }
    return connectionDataSource.findServer(name);
  }

  @override
  Future<List<VpnServer>> getServers({bool forceRefresh = false}) async {
    AppLogger.d('VPN', 'repo.getServers forceRefresh=$forceRefresh mem=${_servers.length}');
    // Fresh installs start on the 4 config-less mocks: seed from the
    // bundled snapshot first (fast, local, ~100ms) so the very first paint
    // already shows ~98 real relays while the network fetch works in the
    // background. Memoized — runs once per process.
    if (identical(_servers, VpnServer.availableServers)) {
      final snapshot = await _loadSnapshot();
      if (snapshot.isNotEmpty) {
        _servers = snapshot;
        AppLogger.i('VPN', 'repo seeded from snapshot (${snapshot.length})');
      }
    }
    // Fast path: warm memory on plain (non-forced) loads.
    if (!forceRefresh && _servers != VpnServer.availableServers) {
      AppLogger.d('VPN', 'repo.getServers → memory (${_servers.length})');
      return _servers;
    }
    // Offline-first boot: serve sqflite rows when present so the UI never
    // waits on the network. A forced refresh skips straight to the network.
    if (!forceRefresh) {
      try {
        final cached = await localDataSource.loadCachedServers();
        AppLogger.d('VPN', 'repo offline-first cache → ${cached.length}');
        if (cached.isNotEmpty) {
          _servers = cached;
          AppLogger.i('VPN', 'repo.getServers → offline cache (${cached.length})');
          return cached;
        }
      } catch (e) {
        AppLogger.w('VPN', 'offline cache miss, trying network', e);
        // Fall through to network.
      }
    }
    try {
      AppLogger.i('VPN', 'repo fetching network (force=$forceRefresh)…');
      final netSw = Stopwatch()..start();
      final servers = await gateDataSource.fetchServers(
        forceRefresh: forceRefresh,
      );
      AppLogger.i(
        'VPN',
        'repo network → ${servers.length} servers '
        'in ${netSw.elapsedMilliseconds}ms',
      );
      // Merge, don't replace: brand-new relays join, relays we already
      // knew keep their place when the fetch omits them (a relay missing
      // from one fetch is usually flapping, not dead), and fresh rows win
      // every field (score/ping/config). Config-less placeholders are
      // dropped the moment live data exists.
      _servers = _mergeServers(_servers, servers);
      // Persist JSON for offline boot WITHOUT blocking the UI: the list is
      // already parsed, so emit it now and let the sqflite write (~100 rows
      // with big base64 configs) finish in the background. Awaiting it here
      // is what held the refresh spinner long after the fast API responded.
      try {
        final json = await gateDataSource.fetchJson();
        unawaited(_persistCache(json, servers));
      } catch (e) {
        unawaited(_persistCache(null, servers));
        AppLogger.w('VPN', 'repo cache payload fallback', e);
      }
      return servers;
    } catch (e, st) {
      AppLogger.e('VPN', 'repo network failed — fallback chain', e, st);
      // Network failed: sqflite -> bundled snapshot -> give up loudly.
      try {
        final cached = await localDataSource.loadCachedServers();
        if (cached.isNotEmpty) {
          _servers = cached;
          AppLogger.w('VPN', 'repo fallback → cache (${cached.length})');
          return cached;
        }
      } catch (_) {}
      final snapshot = await _loadSnapshot();
      if (snapshot.isNotEmpty) {
        _servers = snapshot;
        AppLogger.w(
          'VPN',
          'repo fallback → bundled snapshot (${snapshot.length}, '
          'may be stale — refresh when online)',
        );
        return snapshot;
      }
      if (_servers.isEmpty) _servers = VpnServer.availableServers;
      // Never silently serve config-less mocks as a "loaded" list: with no
      // usable relay the UI would show 4 dead entries and no error. Throw so
      // the bloc surfaces the failure + Retry instead.
      if (!_servers.any((s) => s.isVpnGate)) {
        AppLogger.w('VPN', 'repo fallback has no live relay — throwing');
        throw const VpnException(
          'unreachable',
          'VPNGate is unreachable. Check your connection (or try mobile data vs Wi-Fi) and tap Retry.',
        );
      }
      AppLogger.w('VPN', 'repo fallback → memory (${_servers.length})');
      return _servers;
    }
  }

  /// Reads the snapshot baked by `dart run tool/fetch_snapshot.dart`.
  /// Memoized; empty (never throws) when the asset is missing/corrupt.
  Future<List<VpnServer>> _loadSnapshot() async {
    if (_snapshot != null) return _snapshot!;
    try {
      final raw = await rootBundle.loadString('assets/servers_snapshot.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      _snapshot = VpnServerModel.serversFromJson(decoded);
      AppLogger.i('VPN', 'snapshot parsed (${_snapshot!.length} servers)');
    } catch (e) {
      AppLogger.w('VPN', 'bundled snapshot unavailable: $e');
      _snapshot = const [];
    }
    return _snapshot!;
  }

  /// Union of [current] and [fresh] keyed by stable relay id (hostName).
  /// Fresh rows overwrite everything (score/ping/sessions/config);
  /// previously-known usable relays missing from this fetch are kept;
  /// config-less placeholders are dropped once live data exists.
  /// Result is sorted by score, like the parser output.
  static List<VpnServer> _mergeServers(
    List<VpnServer> current,
    List<VpnServer> fresh,
  ) {
    final byId = <String, VpnServer>{};
    for (final s in current) {
      if (s.isVpnGate) byId[s.id] = s;
    }
    final kept = byId.length;
    for (final s in fresh) {
      byId[s.id] = s;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    AppLogger.i(
      'VPN',
      'repo merge: ${fresh.length} fresh + $kept kept → ${merged.length}',
    );
    return merged;
  }

  /// Background sqflite write. Never throws — a full disk must not break
  /// the live list. Timed so logcat shows if the disk (not the API) is slow.
  Future<void> _persistCache(    List<Map<String, dynamic>>? json,
    List<VpnServer> servers,
  ) async {
    final sw = Stopwatch()..start();
    try {
      if (json != null && json.isNotEmpty) {
        await localDataSource.cacheServers(json);
      } else {
        await localDataSource.cacheServers(
          servers.map((s) => s.toJson()).toList(),
        );
      }
      AppLogger.i(
        'VPN',
        'repo offline cache write done in ${sw.elapsedMilliseconds}ms',
      );
    } catch (e) {
      AppLogger.w('VPN', 'repo offline cache write failed', e);
    }
  }

  @override
  Future<VpnServer?> getBestServer() async {
    AppLogger.d('VPN', 'repo.getBestServer');
    try {
      final best = await localDataSource.loadBestServer();
      if (best != null) {
        AppLogger.d('VPN', 'repo best → cache ${best.id}');
        return best;
      }
    } catch (_) {}
    if (_servers.isNotEmpty) {
      final pool = _servers.where((s) => s.ping >= 0).toList();
      final candidates = pool.isEmpty ? _servers : pool;
      candidates.sort((a, b) {
        final score = b.score.compareTo(a.score);
        if (score != 0) return score;
        return a.ping.compareTo(b.ping);
      });
      return candidates.first;
    }
    return null;
  }

  @override
  Future<List<VpnServer>> searchServers(String query) async {
    AppLogger.d('VPN', 'repo.search "$query"');
    try {
      final r = await localDataSource.loadCachedServers(query: query);
      AppLogger.d('VPN', 'repo.search → ${r.length}');
      return r;
    } catch (_) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return _servers;
      return _servers
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.hostName.toLowerCase().contains(q) ||
                s.ip.contains(q),
          )
          .toList();
    }
  }

  @override
  Stream<String> get connectionDetailStream {
    try {
      return connectionDataSource.stageTextStream;
    } catch (e) {
      AppLogger.w('VPN', 'detail stream unavailable: $e');
      return const Stream.empty();
    }
  }

  @override
  String get lastConnectionDetail {
    try {
      return connectionDataSource.lastStageText;
    } catch (_) {
      return '';
    }
  }

  @override
  Future<bool> syncTunnelState() async {
    try {
      return await connectionDataSource.syncTunnelState();
    } catch (e) {
      AppLogger.w('VPN', 'repo syncTunnelState failed: $e');
      return false;
    }
  }
}
