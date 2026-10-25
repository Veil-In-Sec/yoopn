import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/domain/repositories/vpn_repository.dart';
import 'package:yoopn/features/dashboard/domain/usecases/dashboard_use_cases.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

const _relay = VpnServer(
  name: 'Japan',
  flag: '🇯🇵',
  hostName: 'public-vpn-1',
  ip: '1.2.3.4',
  score: 9000,
  ping: 11,
  openVpnConfig: 'Y2xpZW50CmRldiB0dW4K',
);

const _relay2 = VpnServer(
  name: 'Korea',
  flag: '🇰🇷',
  hostName: 'public-vpn-2',
  ip: '5.6.7.8',
  score: 8000,
  ping: 20,
  openVpnConfig: 'Y2xpZW50CmRldiB0dW4K',
);

class _FakeVpnRepository implements VpnRepository {
  final List<VpnServer> relays;
  final _details = StreamController<String>.broadcast();

  Object? connectError;
  Object? disconnectError;
  Duration connectDelay = Duration.zero;
  int connectCalls = 0;
  int disconnectCalls = 0;

  _FakeVpnRepository({this.relays = const [_relay, _relay2]});

  @override
  Future<void> connect(VpnServer server) async {
    connectCalls++;
    if (connectDelay > Duration.zero) {
      await Future<void>.delayed(connectDelay);
    }
    final err = connectError;
    if (err != null) throw err;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    final err = disconnectError;
    if (err != null) throw err;
  }

  @override
  VpnServer? findServer(String name) {
    for (final s in relays) {
      if (s.matchesId(name)) return s;
    }
    return null;
  }

  @override
  Future<List<VpnServer>> getServers({bool forceRefresh = false}) async =>
      relays;

  @override
  Future<VpnServer?> getBestServer() async => relays.isEmpty ? null : relays.first;

  @override
  Future<List<VpnServer>> searchServers(String query) async => relays;

  @override
  Stream<String> get connectionDetailStream => _details.stream;

  @override
  String get lastConnectionDetail => '';

  @override
  Future<bool> syncTunnelState() async => false;

  void emitDetail(String text) => _details.add(text);

  Future<void> dispose() => _details.close();
}

class _ShrinkingRepository implements VpnRepository {
  List<VpnServer> relays;
  final _details = StreamController<String>.broadcast();

  _ShrinkingRepository({required this.relays});

  @override
  Future<void> connect(VpnServer server) async {}

  @override
  Future<void> disconnect() async {}

  @override
  VpnServer? findServer(String name) {
    for (final s in relays) {
      if (s.matchesId(name)) return s;
    }
    return null;
  }

  @override
  Future<List<VpnServer>> getServers({bool forceRefresh = false}) async =>
      relays;

  @override
  Future<VpnServer?> getBestServer() async => null;

  @override
  Future<List<VpnServer>> searchServers(String query) async => relays;

  @override
  Stream<String> get connectionDetailStream => _details.stream;

  @override
  String get lastConnectionDetail => '';

  @override
  Future<bool> syncTunnelState() async => false;

  Future<void> dispose() => _details.close();
}

void main() {
  late _FakeVpnRepository repository;
  late VpnBloc bloc;

  VpnBloc build() => VpnBloc(useCases: DashboardUseCases.fromRepository(repository));

  setUp(() {
    repository = _FakeVpnRepository();
    bloc = build();
  });

  tearDown(() async {
    await bloc.close();
    await repository.dispose();
  });

  group('connect', () {
    test('toggled on a disconnected state connects and records the timer',
        () async {
      await repository.getServers();
      bloc.add(const VpnServersRequested());
      await bloc.stream.firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      bloc.add(const VpnServerSelected('public-vpn-1'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-1');

      bloc.add(const VpnToggled());
      final connected =
          await bloc.stream.firstWhere((s) => s.status == VpnStatus.connected);

      expect(repository.connectCalls, 1);
      expect(connected.status, VpnStatus.connected);
      expect(connected.connectedSince, isNotNull);
    });

    test('stays disconnected and surfaces the failure message', () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      bloc.add(const VpnServerSelected('public-vpn-1'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-1');

      repository.connectError =
          const VpnException('timeout', 'Stuck at "assign_ip"');
      bloc.add(const VpnToggled());
      final failed =
          await bloc.stream.firstWhere((s) => s.errorMessage != null);

      expect(failed.status, VpnStatus.disconnected);
      expect(failed.errorMessage, contains('assign_ip'));
      expect(failed.connectedSince, isNull);
    });

    test('refuses to connect when the selection no longer exists', () async {
      repository = _FakeVpnRepository(relays: const []);
      await bloc.close();
      bloc = build();

      bloc.add(const VpnToggled());
      final failed =
          await bloc.stream.firstWhere((s) => s.errorMessage != null);

      expect(repository.connectCalls, 0);
      expect(failed.errorMessage, contains('No live servers'));
    });
  });

  group('cancel', () {
    test('toggled while connecting cancels instead of being ignored',
        () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      bloc.add(const VpnServerSelected('public-vpn-1'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-1');

      repository.connectDelay = const Duration(milliseconds: 80);
      bloc.add(const VpnToggled());
      await bloc.stream
          .firstWhere((s) => s.status == VpnStatus.connecting);

      bloc.add(const VpnToggled());
      final back = await bloc.stream.firstWhere(
        (s) => s.status == VpnStatus.disconnected,
      );

      expect(repository.disconnectCalls, 1);
      expect(back.status, VpnStatus.disconnected);
    });
  });

  group('server selection', () {
    test('selecting while connected is blocked', () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);
      bloc.add(const VpnServerSelected('public-vpn-1'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-1');

      bloc.add(const VpnToggled());
      await bloc.stream.firstWhere((s) => s.status == VpnStatus.connected);

      bloc.add(const VpnServerSelected('public-vpn-1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.status, VpnStatus.connected);
      expect(bloc.state.server, isNot('unknown-server'));
      expect(bloc.state.server, 'public-vpn-1');
    });

    test('selecting an unknown server leaves the selection unchanged',
        () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);
      final before = bloc.state.server;

      bloc.add(const VpnServerSelected('does-not-exist'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.server, before);
    });
  });

  group('connection detail', () {
    test('detail text from the tunnel reaches state while connecting',
        () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      bloc.add(const VpnServerSelected('public-vpn-1'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-1');

      repository.connectDelay = const Duration(milliseconds: 60);
      bloc.add(const VpnToggled());
      await bloc.stream
          .firstWhere((s) => s.status == VpnStatus.connecting);

      repository.emitDetail('Authenticating…');
      final detailed = await bloc.stream
          .firstWhere((s) => s.connectionDetail == 'Authenticating…');

      expect(detailed.connectionDetail, 'Authenticating…');
      expect(detailed.connectStartedAt, isNotNull);
    });

    test('detail is cleared once disconnected', () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);
      bloc.add(const VpnServerSelected('public-vpn-1'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-1');
      bloc.add(const VpnToggled());
      await bloc.stream.firstWhere((s) => s.status == VpnStatus.connected);

      bloc.add(const VpnToggled());
      final off = await bloc.stream
          .firstWhere((s) => s.status == VpnStatus.disconnected);

      expect(off.connectionDetail, isEmpty);
      expect(off.connectStartedAt, isNull);
      expect(off.connectedSince, isNull);
    });
  });

  group('no default selection', () {
    test('keeps the selection empty on first load (no default)', () async {
      bloc.add(const VpnServersRequested());
      final loaded = await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      expect(loaded.server, isEmpty);
      expect(loaded.servers, isNotEmpty);
    });

    test('connect requires an explicit selection', () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      bloc.add(const VpnToggled());
      final failed =
          await bloc.stream.firstWhere((s) => s.errorMessage != null);

      expect(repository.connectCalls, 0);
      expect(failed.status, VpnStatus.disconnected);
      expect(failed.errorMessage, contains('Select a server'));
    });

    test('a picked relay that vanished clears the selection',
        () async {
      final repo = _ShrinkingRepository(relays: const [_relay]);
      final shrinkingBloc =
          VpnBloc(useCases: DashboardUseCases.fromRepository(repo));
      addTearDown(shrinkingBloc.close);
      addTearDown(repo.dispose);

      shrinkingBloc.add(const VpnServersRequested());
      await shrinkingBloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);
      expect(shrinkingBloc.state.server, isEmpty);
      shrinkingBloc.add(const VpnServerSelected('public-vpn-1'));
      await shrinkingBloc.stream
          .firstWhere((s) => s.server == 'public-vpn-1');

      // Refresh hands back a list without the picked relay: the selection
      // must clear instead of silently re-picking something else.
      repo.relays = const [_relay2];
      shrinkingBloc.add(const VpnServersRequested(forceRefresh: true));
      final after = await shrinkingBloc.stream.firstWhere(
        (s) =>
            s.serversStatus == VpnServersStatus.loaded &&
            s.server != 'public-vpn-1',
      );

      expect(after.server, isEmpty);
    });

    test('keeps a manual selection across refreshes', () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      bloc.add(const VpnServerSelected('public-vpn-2'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-2');

      bloc.add(const VpnServersRequested(forceRefresh: true));
      final after = await bloc.stream.firstWhere(
        (s) => s.serversStatus == VpnServersStatus.loaded && s.server != '',
      );

      expect(after.server, 'public-vpn-2');
    });
  });

  group('duplicate connect guard', () {
    test('only one connect runs per successful attempt', () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      bloc.add(const VpnServerSelected('public-vpn-1'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-1');

      bloc.add(const VpnToggled());
      await bloc.stream.firstWhere((s) => s.status == VpnStatus.connected);
      expect(repository.connectCalls, 1);

      bloc.add(const VpnToggled());
      await bloc.stream.firstWhere((s) => s.status == VpnStatus.disconnected);

      bloc.add(const VpnToggled());
      await bloc.stream.firstWhere((s) => s.status == VpnStatus.connected);
      expect(repository.connectCalls, 2);
    });

    test('guard is released after a failure so the user can retry', () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      bloc.add(const VpnServerSelected('public-vpn-1'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-1');

      repository.connectError = const VpnException('timeout', 'too slow');
      bloc.add(const VpnToggled());
      await bloc.stream.firstWhere((s) => s.errorMessage != null);
      expect(repository.connectCalls, 1);

      repository.connectError = null;
      bloc.add(const VpnToggled());
      await bloc.stream.firstWhere((s) => s.status == VpnStatus.connected);

      expect(repository.connectCalls, 2);
    });

    test('guard is released after a cancel so reconnect works', () async {
      bloc.add(const VpnServersRequested());
      await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      bloc.add(const VpnServerSelected('public-vpn-1'));
      await bloc.stream.firstWhere((s) => s.server == 'public-vpn-1');

      repository.connectDelay = const Duration(milliseconds: 60);
      bloc.add(const VpnToggled());
      await bloc.stream
          .firstWhere((s) => s.status == VpnStatus.connecting);
      bloc.add(const VpnToggled());
      await bloc.stream.firstWhere(
        (s) => s.status == VpnStatus.disconnected && !s.isLoadingServers,
      );

      final before = repository.connectCalls;
      repository.connectDelay = Duration.zero;
      bloc.add(const VpnToggled());
      await bloc.stream.firstWhere((s) => s.status == VpnStatus.connected);

      expect(repository.connectCalls, greaterThan(before));
    });
  });

  group('servers request', () {
    test('serves the live list and keeps the current selection', () async {
      bloc.add(const VpnServersRequested());
      final loaded = await bloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      expect(loaded.servers.length, 2);
      expect(loaded.server, isEmpty);
    });

    test('forceRefresh is forwarded to the repository', () async {
      var seenForceRefresh = false;
      final probe = _ProbeRepository(onGetServers: (force) {
        seenForceRefresh = force;
      });
      final probeBloc = VpnBloc(
        useCases: DashboardUseCases.fromRepository(probe),
      );
      addTearDown(probeBloc.close);
      addTearDown(probe.dispose);

      probeBloc.add(const VpnServersRequested(forceRefresh: true));
      await probeBloc.stream
          .firstWhere((s) => s.serversStatus == VpnServersStatus.loaded);

      expect(seenForceRefresh, isTrue);
    });
  });
}

class _ProbeRepository implements VpnRepository {
  final void Function(bool forceRefresh) onGetServers;
  final _details = StreamController<String>.broadcast();

  _ProbeRepository({required this.onGetServers});

  @override
  Future<List<VpnServer>> getServers({bool forceRefresh = false}) async {
    onGetServers(forceRefresh);
    return const [_relay];
  }

  @override
  Stream<String> get connectionDetailStream => _details.stream;

  @override
  String get lastConnectionDetail => '';

  @override
  Future<bool> syncTunnelState() async => false;

  Future<void> dispose() => _details.close();

  @override
  Future<void> connect(VpnServer server) async {}

  @override
  Future<void> disconnect() async {}

  @override
  VpnServer? findServer(String name) =>
      _relay.matchesId(name) ? _relay : null;

  @override
  Future<VpnServer?> getBestServer() async => _relay;

  @override
  Future<List<VpnServer>> searchServers(String query) async => const [_relay];
}