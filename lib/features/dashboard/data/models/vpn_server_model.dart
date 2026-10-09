import 'dart:convert';

import '../../domain/entities/vpn_server.dart';

/// VPNGate pipeline: CSV -> JSON -> [VpnServer].
///
/// Stage 1 ([csvToJson]): raw `https://www.vpngate.net/api/iphone/` CSV text
///   becomes a JSON-compatible `List<Map<String, dynamic>>`.
/// Stage 2 ([serversFromJson]): that JSON becomes typed [VpnServer] objects
///   which the rest of the app (repository / bloc / UI) consumes.
/// Stage 3 ([parseCsv]): convenience chaining stage 1 + 2.
///
/// CSV columns (15):
/// HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,
/// Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,
/// OpenVPN_ConfigData_Base64
class VpnServerModel extends VpnServer {
  const VpnServerModel({
    required super.name,
    required super.flag,
    super.hostName = '',
    super.ip = '',
    super.countryShort = '',
    super.countryLong = '',
    super.score = 0,
    super.ping = -1,
    super.speed = 0,
    super.sessions = 0,
    super.uptime = 0,
    super.openVpnConfig = '',
  });

  /// JSON keys produced by [csvToJson] and consumed by [fromJson].
  static const jsonKeys = <String>[
    'hostName',
    'ip',
    'score',
    'ping',
    'speed',
    'countryLong',
    'countryShort',
    'sessions',
    'uptime',
    'totalUsers',
    'totalTraffic',
    'logType',
    'operator',
    'message',
    'openVpnConfig',
    'name',
    'flag',
  ];

  // ------------------------------------------------------------------
  // Stage 1: CSV -> JSON
  // ------------------------------------------------------------------

  /// Convert a full VPNGate CSV payload into JSON-compatible maps.
  ///
  /// Skips `*`/`#` meta lines, tolerates commas inside Message (col 13)
  /// by treating the first 13 cols and the last col as fixed.
  static List<Map<String, dynamic>> csvToJson(String csv) {
    final json = <Map<String, dynamic>>[];
    for (final rawLine in const LineSplitter().convert(csv)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('*') || line.startsWith('#')) continue;
      final row = csvLineToJson(line);
      if (row != null) json.add(row);
    }
    return json;
  }

  /// Convert one CSV data line into a JSON map. Null when malformed.
  static Map<String, dynamic>? csvLineToJson(String line) {
    final parts = line.split(',');
    if (parts.length < 15) return null;

    late final String hostName;
    late final String ip;
    late final String scoreRaw;
    late final String pingRaw;
    late final String speedRaw;
    late final String countryLong;
    late final String countryShort;
    late final String sessionsRaw;
    late final String uptimeRaw;
    late final String totalUsersRaw;
    late final String totalTrafficRaw;
    late final String logType;
    late final String operatorName;
    late final String message;
    late final String configBase64;

    if (parts.length == 15) {
      hostName = parts[0].trim();
      ip = parts[1].trim();
      scoreRaw = parts[2].trim();
      pingRaw = parts[3].trim();
      speedRaw = parts[4].trim();
      countryLong = parts[5].trim();
      countryShort = parts[6].trim();
      sessionsRaw = parts[7].trim();
      uptimeRaw = parts[8].trim();
      totalUsersRaw = parts[9].trim();
      totalTrafficRaw = parts[10].trim();
      logType = parts[11].trim();
      operatorName = parts[12].trim();
      message = parts[13].trim();
      configBase64 = parts[14].trim();
    } else {
      // Extra commas live inside Message: first 13 cols fixed, last col
      // fixed, everything between index 13..n-2 is Message.
      hostName = parts[0].trim();
      ip = parts[1].trim();
      scoreRaw = parts[2].trim();
      pingRaw = parts[3].trim();
      speedRaw = parts[4].trim();
      countryLong = parts[5].trim();
      countryShort = parts[6].trim();
      sessionsRaw = parts[7].trim();
      uptimeRaw = parts[8].trim();
      totalUsersRaw = parts[9].trim();
      totalTrafficRaw = parts[10].trim();
      logType = parts[11].trim();
      operatorName = parts[12].trim();
      message = parts.sublist(13, parts.length - 1).join(',').trim();
      configBase64 = parts.last.trim();
    }

    if (hostName.isEmpty || ip.isEmpty) return null;
    if (configBase64.isEmpty) return null;

    final short = countryShort.toUpperCase();
    final displayName = countryLong.isNotEmpty ? countryLong : short;

    return <String, dynamic>{
      'hostName': hostName,
      'ip': ip,
      'score': int.tryParse(scoreRaw) ?? 0,
      'ping': int.tryParse(pingRaw) ?? -1,
      'speed': int.tryParse(speedRaw) ?? 0,
      'countryLong': countryLong,
      'countryShort': short,
      'sessions': int.tryParse(sessionsRaw) ?? 0,
      'uptime': int.tryParse(uptimeRaw) ?? 0,
      'totalUsers': int.tryParse(totalUsersRaw) ?? 0,
      'totalTraffic': int.tryParse(totalTrafficRaw) ?? 0,
      'logType': logType,
      'operator': operatorName,
      'message': message,
      'openVpnConfig': configBase64,
      // Derived display fields so JSON alone can render UI.
      'name': displayName,
      'flag': VpnServer.flagFromCountryCode(short),
    };
  }

  /// Encode [csvToJson] output as a JSON string (for caching / tests).
  static String csvToJsonString(String csv) => jsonEncode(csvToJson(csv));

  // ------------------------------------------------------------------
  // Stage 2: JSON -> typed model (wires the rest of the app)
  // ------------------------------------------------------------------

  /// Build a typed model from a [csvToJson] map.
  factory VpnServerModel.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      if (v is num) return v.toInt();
      return 0;
    }

    String asString(Object? v) => (v ?? '').toString().trim();

    final countryLong = asString(json['countryLong']);
    final countryShort = asString(json['countryShort']).toUpperCase();
    final name = asString(json['name']).isNotEmpty
        ? asString(json['name'])
        : (countryLong.isNotEmpty ? countryLong : countryShort);
    final flag = asString(json['flag']).isNotEmpty
        ? asString(json['flag'])
        : VpnServer.flagFromCountryCode(countryShort);

    return VpnServerModel(
      name: name,
      flag: flag,
      hostName: asString(json['hostName']),
      ip: asString(json['ip']),
      countryShort: countryShort,
      countryLong: countryLong,
      score: asInt(json['score']),
      ping: json.containsKey('ping') ? asInt(json['ping']) : -1,
      speed: asInt(json['speed']),
      sessions: asInt(json['sessions']),
      uptime: asInt(json['uptime']),
      openVpnConfig: asString(json['openVpnConfig']),
    );
  }

  /// Convert JSON lists (e.g. from cache / tests) into sorted servers.
  static List<VpnServer> serversFromJson(List<dynamic> jsonList) {
    final servers = <VpnServer>[];
    for (final item in jsonList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if ((map['hostName'] ?? '').toString().isEmpty) continue;
      if ((map['openVpnConfig'] ?? '').toString().isEmpty) continue;
      servers.add(VpnServerModel.fromJson(map));
    }
    servers.sort((a, b) => b.score.compareTo(a.score));
    return servers;
  }

  /// Decode a [csvToJsonString] / cached payload back into servers.
  static List<VpnServer> serversFromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) return [];
    return serversFromJson(decoded);
  }

  // ------------------------------------------------------------------
  // Stage 3: convenience CSV -> JSON -> servers
  // ------------------------------------------------------------------

  /// Parse a full CSV payload into servers (CSV -> JSON -> models).
  static List<VpnServer> parseCsv(String csv) =>
      serversFromJson(csvToJson(csv));

  /// Parse one CSV data line directly into a server. Null when malformed.
  static VpnServer? fromCsvLine(String line) {
    final row = csvLineToJson(line);
    if (row == null) return null;
    return VpnServerModel.fromJson(row);
  }
}
