class VpnServer {
  const VpnServer({required this.name, required this.flag});

  final String name;
  final String flag;

  static const List<VpnServer> availableServers = [
    VpnServer(name: 'United States', flag: '🇺🇸'),
    VpnServer(name: 'United Kingdom', flag: '🇬🇧'),
    VpnServer(name: 'Germany', flag: '🇩🇪'),
    VpnServer(name: 'Singapore', flag: '🇸🇬'),
  ];

  @override
  bool operator ==(Object other) =>
      other is VpnServer && other.name == name && other.flag == flag;

  @override
  int get hashCode => Object.hash(name, flag);
}
