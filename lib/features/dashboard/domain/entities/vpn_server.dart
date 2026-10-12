import 'dart:convert';

class VpnServer {
  const VpnServer({
    required this.name,
    required this.flag,
    this.hostName = '',
    this.ip = '',
    this.countryShort = '',
    this.countryLong = '',
    this.score = 0,
    this.ping = -1,
    this.speed = 0,
    this.sessions = 0,
    this.uptime = 0,
    this.openVpnConfig = '',
  });

  final String name;
  final String flag;

  final String hostName;

  final String ip;

  final String countryShort;

  final String countryLong;

  final int score;

  final int ping;

  final int speed;

  final int sessions;

  final int uptime;

  final String openVpnConfig;

  String get id => hostName.isNotEmpty ? hostName : name;

  bool get isVpnGate => hostName.isNotEmpty && openVpnConfig.isNotEmpty;

  String get decodedOpenVpnConfig {
    if (openVpnConfig.isEmpty) return '';
    try {
      final normalized = openVpnConfig.trim().replaceAll(RegExp(r'\s+'), '');
      return utf8.decode(base64.decode(normalized), allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  String get speedText {
    if (speed <= 0) return '—';
    final mbps = speed / 1000000;
    if (mbps >= 1000) return '${(mbps / 1000).toStringAsFixed(2)} Gbps';
    if (mbps >= 1) return '${mbps.toStringAsFixed(1)} Mbps';
    return '${(speed / 1000).toStringAsFixed(0)} Kbps';
  }

  String get pingText => ping < 0 ? '—' : '$ping ms';

  static const List<VpnServer> availableServers = [
    VpnServer(name: 'United States', flag: '🇺🇸'),
    VpnServer(name: 'United Kingdom', flag: '🇬🇧'),
    VpnServer(name: 'Germany', flag: '🇩🇪'),
    VpnServer(name: 'Singapore', flag: '🇸🇬'),
  ];

  bool matchesId(String query) {
    if (query.isEmpty) return false;
    return query == hostName ||
        query == ip ||
        query == name ||
        query == id;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hostName': hostName,
    'ip': ip,
    'score': score,
    'ping': ping,
    'speed': speed,
    'countryLong': countryLong,
    'countryShort': countryShort,
    'sessions': sessions,
    'uptime': uptime,
    'openVpnConfig': openVpnConfig,
    'name': name,
    'flag': flag,
  };

  static String flagFromCountryCode(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.length != 2) return '🌐';
    const base = 0x1F1E6;
    final first = upper.codeUnitAt(0) - 0x41 + base;
    final second = upper.codeUnitAt(1) - 0x41 + base;
    if (first < base || first > base + 25) return '🌐';
    if (second < base || second > base + 25) return '🌐';
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  @override
  bool operator ==(Object other) =>
      other is VpnServer &&
      other.name == name &&
      other.flag == flag &&
      other.hostName == hostName &&
      other.ip == ip;

  @override
  int get hashCode => Object.hash(name, flag, hostName, ip);
}
