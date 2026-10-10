import '../repositories/vpn_repository.dart';
import 'connect_vpn.dart';
import 'disconnect_vpn.dart';
import 'get_best_server.dart';
import 'get_vpn_servers.dart';
import 'search_servers.dart';
import 'select_vpn_server.dart';
import 'sync_tunnel_state.dart';
import 'watch_connection_detail.dart';

class DashboardUseCases {
  const DashboardUseCases({
    required this.connectVpn,
    required this.disconnectVpn,
    required this.selectVpnServer,
    required this.getVpnServers,
    required this.getBestServer,
    required this.searchServers,
    required this.watchConnectionDetail,
    required this.syncTunnelState,
  });

  final ConnectVpnUseCase connectVpn;
  final DisconnectVpnUseCase disconnectVpn;
  final SelectVpnServerUseCase selectVpnServer;
  final GetVpnServersUseCase getVpnServers;
  final GetBestServerUseCase getBestServer;
  final SearchServersUseCase searchServers;
  final WatchConnectionDetailUseCase watchConnectionDetail;
  final SyncTunnelStateUseCase syncTunnelState;

  factory DashboardUseCases.fromRepository(VpnRepository repository) {
    return DashboardUseCases(
      connectVpn: ConnectVpnUseCase(repository),
      disconnectVpn: DisconnectVpnUseCase(repository),
      selectVpnServer: SelectVpnServerUseCase(repository),
      getVpnServers: GetVpnServersUseCase(repository),
      getBestServer: GetBestServerUseCase(repository),
      searchServers: SearchServersUseCase(repository),
      watchConnectionDetail: WatchConnectionDetailUseCase(repository),
      syncTunnelState: SyncTunnelStateUseCase(repository),
    );
  }
}
