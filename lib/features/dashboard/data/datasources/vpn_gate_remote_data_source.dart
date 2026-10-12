import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import '../../domain/entities/vpn_server.dart';
import '../models/vpn_server_model.dart';

abstract interface class VpnGateRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchJson({bool forceRefresh = false});

  Future<List<VpnServer>> fetchServers({bool forceRefresh = false});

  String? get lastJsonString;

  DateTime? get lastFetchedAt;
}

class VpnGateRemoteDataSourceImpl implements VpnGateRemoteDataSource {
  VpnGateRemoteDataSourceImpl({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
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

  /// In-flight dedup per kind: concurrent plain/forced fetches join instead
  /// of stampeding the network + isolate parser.
  Future<List<Map<String, dynamic>>>? _jsonInflight;
  Future<List<Map<String, dynamic>>>? _jsonInflightForced;

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
    final Future<List<Map<String, dynamic>>> pending;
    if (forceRefresh) {
      pending = _jsonInflightForced ??= _fetchAndParse();
    } else {
      pending = _jsonInflight ??= _fetchAndParse();
    }
    try {
      return await pending;
    } finally {
      if (forceRefresh) {
        if (identical(_jsonInflightForced, pending)) {
          _jsonInflightForced = null;
        }
      } else if (identical(_jsonInflight, pending)) {
        _jsonInflight = null;
      }
    }
  }

  /// Network + isolate parse + cache commit. Single flight per kind.
  Future<List<Map<String, dynamic>>> _fetchAndParse() async {
    final netSw = Stopwatch()..start();
    final csv = await _fetchRawCsv();
    netSw.stop();
    AppLogger.i(
      'GATE',
      'TIMING network done in ${netSw.elapsedMilliseconds}ms '
      '(${csv.length} chars)',
    );
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

  static const _attempts = 5;

  Future<String> _fetchRawCsv() async {
    Object? lastError;
    for (var attempt = 0; attempt < _attempts; attempt++) {
      final attemptSw = Stopwatch()..start();
      try {
        final response = await _dio.get<String>(
          endpoint,
          options: Options(
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
