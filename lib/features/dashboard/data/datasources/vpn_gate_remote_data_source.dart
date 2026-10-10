import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import '../../domain/entities/vpn_server.dart';
import '../models/vpn_server_model.dart';

abstract interface class VpnGateRemoteDataSource {
  /// Stage 1 output: raw CSV converted to JSON maps. Test hook — inspect
  /// this to verify the CSV -> JSON step without touching UI.
  Future<List<Map<String, dynamic>>> fetchJson({bool forceRefresh = false});

  /// Stage 2 output: JSON wired into typed servers for repository/bloc/UI.
  Future<List<VpnServer>> fetchServers({bool forceRefresh = false});

  /// Last JSON payload as a string (for caching / debugging / tests).
  String? get lastJsonString;

  DateTime? get lastFetchedAt;
}

class VpnGateRemoteDataSourceImpl implements VpnGateRemoteDataSource {
  VpnGateRemoteDataSourceImpl({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              // Fail fast on dead attempts for non-CSV calls. (The CSV fetch
              // itself uses patient per-request timeouts — see _fetchRawCsv.)
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 10),
              responseType: ResponseType.plain,
              headers: const {'Accept': 'text/plain'},
            ),
          );

  static const String endpoint = 'https://www.vpngate.net/api/iphone/';
  static const Duration cacheTtl = Duration(minutes: 15);

  final Dio _dio;
  List<Map<String, dynamic>>? _jsonCache;
  List<VpnServer>? _serverCache;
  DateTime? _fetchedAt;

  @override
  String? get lastJsonString =>
      _jsonCache == null ? null : jsonEncode(_jsonCache);

  @override
  DateTime? get lastFetchedAt => _fetchedAt;

  bool get _cacheValid =>
      _jsonCache != null &&
      _jsonCache!.isNotEmpty &&
      _serverCache != null &&
      _serverCache!.isNotEmpty &&
      _fetchedAt != null &&
      DateTime.now().difference(_fetchedAt!) < cacheTtl;

  @override
  Future<List<Map<String, dynamic>>> fetchJson({
    bool forceRefresh = false,
  }) async {
    AppLogger.d('GATE', 'fetchJson forceRefresh=$forceRefresh cacheValid=$_cacheValid cached=${_jsonCache?.length ?? 0}');
    if (!forceRefresh && _cacheValid) {
      AppLogger.d('GATE', 'fetchJson → memory cache (${_jsonCache!.length} rows)');
      return _jsonCache!;
    }
    final netSw = Stopwatch()..start();
    final csv = await _fetchRawCsv();
    netSw.stop();
    AppLogger.i(
      'GATE',
      'TIMING network done in ${netSw.elapsedMilliseconds}ms '
      '(${csv.length} chars)',
    );
    // Stage 1: CSV -> JSON, in a background isolate. This walks megabytes
    // of text — on the UI thread it janks every animation for up to ~2s on
    // slow phones. `csvToJson` is a pure static function, so `compute` can
    // run it elsewhere; the row maps cross the isolate boundary fine.
    final parseSw = Stopwatch()..start();
    final json = await compute(VpnServerModel.csvToJson, csv);
    parseSw.stop();
    AppLogger.i(
      'GATE',
      'TIMING CSV→JSON ${json.length} rows in ${parseSw.elapsedMilliseconds}ms',
    );
    if (json.isEmpty) {
      throw const FormatException('No VPN servers in VPNGate response');
    }
    // Stage 2 (cached alongside so fetchServers never re-parses CSV).
    final modelSw = Stopwatch()..start();
    final servers = VpnServerModel.serversFromJson(json);
    modelSw.stop();
    AppLogger.i(
      'GATE',
      'TIMING JSON→models ${servers.length} servers '
      'in ${modelSw.elapsedMilliseconds}ms',
    );
    if (servers.isEmpty) {
      throw const FormatException('No VPN servers in VPNGate response');
    }
    _jsonCache = json;
    _serverCache = servers;
    _fetchedAt = DateTime.now();
    AppLogger.i('GATE', 'cached ${servers.length} servers at $_fetchedAt');
    return json;
  }

  @override
  Future<List<VpnServer>> fetchServers({bool forceRefresh = false}) async {
    AppLogger.d('GATE', 'fetchServers forceRefresh=$forceRefresh');
    if (!forceRefresh && _cacheValid) {
      AppLogger.d('GATE', 'fetchServers → memory cache (${_serverCache!.length})');
      return _serverCache!;
    }
    await fetchJson(forceRefresh: forceRefresh);
    AppLogger.i('GATE', 'fetchServers → ${_serverCache!.length} servers');
    return _serverCache!;
  }

  /// Attempts budget for one fetch. Deliberately generous: the visible UI
  /// abandons waiting after 2s (refresh budget) and the SAME fetch keeps
  /// going in the background, where patience is free. Short timeouts here
  /// would kill slow-but-working links that just need 15–20s for megabytes.
  static const _attempts = 5;

  Future<String> _fetchRawCsv() async {
    // Retry transient network errors with growing backoff (1s..4s). Parse
    // errors throw FormatException and are never retried.
    Object? lastError;
    for (var attempt = 0; attempt < _attempts; attempt++) {
      final attemptSw = Stopwatch()..start();
      try {
        final response = await _dio.get<String>(
          endpoint,
          options: Options(
            // Patient per-request overrides (base Dio stays at 10s for
            // everything else): a trickling multi-MB CSV must survive slow
            // handshakes and long idle gaps between chunks.
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 30),
          ),
        );
        final body = response.data ?? '';
        attemptSw.stop();
        AppLogger.i(
          'GATE',
          'TIMING attempt ${attempt + 1}/$_attempts ok in '
          '${attemptSw.elapsedMilliseconds}ms (${body.length} chars)',
        );
        if (body.isEmpty) {
          throw const FormatException('Empty VPNGate response');
        }
        return body;
      } on FormatException {
        rethrow;
      } on DioException catch (e) {
        attemptSw.stop();
        AppLogger.w(
          'GATE',
          'TIMING attempt ${attempt + 1}/$_attempts ${e.type.name} after '
          '${attemptSw.elapsedMilliseconds}ms: ${e.message}',
        );
        final detail =
            e.message ?? e.error?.toString() ?? 'Failed to reach VPNGate';
        lastError = Exception('VPNGate request failed: $detail');
        if (attempt < _attempts - 1) {
          await Future<void>.delayed(Duration(seconds: attempt + 1));
        }
      }
    }
    throw lastError ?? Exception('VPNGate request failed');
  }
}
