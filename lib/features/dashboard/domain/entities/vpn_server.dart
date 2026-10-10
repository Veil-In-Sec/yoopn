import 'dart:convert';

/// VPN server entity.
///
/// For VPNGate servers [name] is the country long name (e.g. "Japan"),
/// [hostName] is the unique VPNGate host (e.g. "public-vpn-119") and is
/// used as the stable selection id. Legacy fallback servers only carry
/// [name] + [flag].
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

  /// VPNGate host name, e.g. "public-vpn-119". Empty for fallback servers.
  final String hostName;

  /// Public IPv4 of the relay.
  final String ip;

  /// ISO 3166-1 alpha-2 country code, e.g. "JP".
  final String countryShort;

  /// Full country name, e.g. "Japan".
  final String countryLong;

  /// VPNGate score (higher is better).
  final int score;

  /// Ping in ms. -1 means unknown.
  final int ping;

  /// Line speed in bits per second.
  final int speed;

  /// Current VPN sessions.
  final int sessions;

  /// Uptime in seconds.
  final int uptime;

  /// Raw base64 OpenVPN config from VPNGate (`OpenVPN_ConfigData_Base64`).
  final String openVpnConfig;

  /// Stable selection id: hostName when available, otherwise name.
  String get id => hostName.isNotEmpty ? hostName : name;

  /// True for live VPNGate relays (carries an OpenVPN config).
  bool get isVpnGate => hostName.isNotEmpty && openVpnConfig.isNotEmpty;

  /// Decoded OpenVPN (.ovpn) config text, or empty string if undecodable.
  String get decodedOpenVpnConfig {
    if (openVpnConfig.isEmpty) return '';
    try {
      // VPNGate sometimes appends whitespace/newlines — strip them.
      final normalized = openVpnConfig.trim().replaceAll(RegExp(r'\s+'), '');
      return utf8.decode(base64.decode(normalized), allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  /// Human readable speed, e.g. "209.8 Mbps".
  String get speedText {
    if (speed <= 0) return '—';
    final mbps = speed / 1000000;
    if (mbps >= 1000) return '${(mbps / 1000).toStringAsFixed(2)} Gbps';
    if (mbps >= 1) return '${mbps.toStringAsFixed(1)} Mbps';
    return '${(speed / 1000).toStringAsFixed(0)} Kbps';
  }

  /// Human readable ping, e.g. "11 ms" or "—".
  String get pingText => ping < 0 ? '—' : '$ping ms';

  static const List<VpnServer> availableServers = [
    VpnServer(name: 'United States', flag: '🇺🇸'),
    VpnServer(name: 'United Kingdom', flag: '🇬🇧'),
    VpnServer(name: 'Germany', flag: '🇩🇪'),
    VpnServer(name: 'Singapore', flag: '🇸🇬'),
  ];

  /// Matches a user selection against hostName, ip, or country name.
  ///
  /// Empty queries never match: placeholder servers carry empty
  /// `hostName`/`ip`, so `'' == hostName` would otherwise resolve an
  /// unselected state (`server == ''`) to the first fallback entry
  /// (United States) which has no OpenVPN config and always fails
  /// with `bad-config`.
  bool matchesId(String query) {
    if (query.isEmpty) return false;
    return query == hostName ||
        query == ip ||
        query == name ||
        query == id;
  }

  /// Serialize for JSON caching / tests. Pairs with `VpnServerModel.fromJson`.
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

  /// ISO country code (e.g. "JP") -> flag emoji (e.g. "🇯🇵").
  static String flagFromCountryCode(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.length != 2) return '🌐';
    const base = 0x1F1E6; // Regional Indicator Symbol Letter A
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
