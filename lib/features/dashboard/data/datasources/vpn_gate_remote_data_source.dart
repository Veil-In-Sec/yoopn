import 'dart:convert';

import 'package:dio/dio.dart';
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
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
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
    final csv = await _fetchRawCsv();
    AppLogger.i('GATE', 'CSV downloaded ${csv.length} chars → parsing…');
    // Stage 1: CSV -> JSON.
    final json = VpnServerModel.csvToJson(csv);
    AppLogger.i('GATE', 'CSV→JSON ${json.length} rows');
    if (json.isEmpty) {
      throw const FormatException('No VPN servers in VPNGate response');
    }
    // Stage 2 (cached alongside so fetchServers never re-parses CSV).
    final servers = VpnServerModel.serversFromJson(json);
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

  Future<String> _fetchRawCsv() async {
    // Retry transient network errors with backoff (1s, 2s). Parse errors
    // throw FormatException and are never retried.
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _dio.get<String>(endpoint);
        final body = response.data ?? '';
        if (body.isEmpty) {
          throw const FormatException('Empty VPNGate response');
        }
        return body;
      } on FormatException {
        rethrow;
      } on DioException catch (e) {
        AppLogger.w('GATE', 'attempt ${attempt + 1}/3 failed: ${e.message}');
        lastError = e;
        final detail =
            e.message ?? e.error?.toString() ?? 'Failed to reach VPNGate';
        lastError = Exception('VPNGate request failed: $detail');
        if (attempt < 2) {
          await Future<void>.delayed(Duration(seconds: attempt + 1));
        }
      }
    }
    throw lastError ?? Exception('VPNGate request failed');
  }
}
