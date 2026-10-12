import '../entities/vpn_server.dart';

/// Single source of truth for relay quality ordering and text search. Used
/// by the bloc (auto-pick), the repository (best/fallback search) and the
/// in-memory cache. Pure domain logic: no dependencies.
///
/// Note: the sqflite queries in `vpn_local_data_source.dart` keep an SQL
/// mirror (`ORDER BY score DESC, ping ASC`, LIKE over name/host/ip/country)
/// because SQL cannot call Dart. Keep the two in sync when changing this.
int compareServersByQuality(VpnServer a, VpnServer b) {
  final score = b.score.compareTo(a.score);
  if (score != 0) return score;
  final ap = a.ping < 0 ? 1 << 30 : a.ping;
  final bp = b.ping < 0 ? 1 << 30 : b.ping;
  return ap.compareTo(bp);
}

bool serverMatchesQuery(VpnServer s, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return s.name.toLowerCase().contains(q) ||
      s.hostName.toLowerCase().contains(q) ||
      s.ip.contains(q) ||
      s.countryShort.toLowerCase().contains(q) ||
      s.countryLong.toLowerCase().contains(q);
}
