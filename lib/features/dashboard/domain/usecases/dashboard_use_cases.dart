import '../repositories/vpn_repository.dart';
import 'connect_vpn.dart';
import 'disconnect_vpn.dart';
import 'select_vpn_server.dart';

class DashboardUseCases {
  const DashboardUseCases({
    required this.connectVpn,
    required this.disconnectVpn,
    required this.selectVpnServer,
  });

  final ConnectVpnUseCase connectVpn;
  final DisconnectVpnUseCase disconnectVpn;
  final SelectVpnServerUseCase selectVpnServer;

  factory DashboardUseCases.fromRepository(VpnRepository repository) {
    return DashboardUseCases(
      connectVpn: ConnectVpnUseCase(repository),
      disconnectVpn: DisconnectVpnUseCase(repository),
      selectVpnServer: SelectVpnServerUseCase(repository),
    );
  }
}
