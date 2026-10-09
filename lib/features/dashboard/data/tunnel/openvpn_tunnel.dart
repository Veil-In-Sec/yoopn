import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/data/tunnel/vpn_tunnel.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

/// Real OpenVPN tunnel backed by `openvpn_flutter`.
///
/// - Android: works once `MainActivity.onActivityResult` forwards to
///   `OpenVPNFlutterPlugin` (see `MainActivity.kt`) + manifest permissions.
/// - iOS: additionally requires a Packet Tunnel Network Extension target
///   (see `ios/VPNExtension/` template + README section below).
/// - Desktop/web/tests: never instantiated — DI falls back to
///   [SimulatedVpnTunnel] there.
///
/// VPNGate public relays use the well-known credentials `vpn` / `vpn`.
class OpenVpnTunnel implements VpnTunnel {
  OpenVpnTunnel({this.connectTimeout = const Duration(seconds: 30)}) {
    _engine = OpenVPN(
      onVpnStatusChanged: _onEngineStatus,
      onVpnStageChanged: _onEngineStage,
    );
    AppLogger.d('TUNNEL', 'OpenVpnTunnel created (real, openvpn_flutter)');
  }

  /// Public VPNGate credentials — documented by University of Tsukuba.
  static const vpnUsername = 'vpn';
  static const vpnPassword = 'vpn';

  /// iOS Network Extension identifiers.
  ///
  /// MUST match the Xcode targets you create manually:
  /// - App Group capability on Runner + VPNExtension: `group.com.vis.yoopn.vpn`
  /// - Extension bundle id: `com.vis.yoopn.VPNExtension`
  static const iosGroupId = 'group.com.vis.yoopn.vpn';
  static const iosProviderBundleId = 'com.vis.yoopn.VPNExtension';
  static const iosLocalizedDescription = 'YooPN';

  final Duration connectTimeout;

  late final OpenVPN _engine;
  final _controller = StreamController<VpnTunnelStatus>.broadcast();
  final _stageController = StreamController<String>.broadcast();
  VpnTunnelStatus _status = VpnTunnelStatus.disconnected;
  bool _initialized = false;
  Completer<void>? _connectCompleter;
  String _lastRawStage = '';
  String _stageText = '';
  DateTime? _connectStartedAt;
  Timer? _pollTimer;
  bool _cancelRequested = false;

  @override
  Stream<VpnTunnelStatus> get statusStream => _controller.stream;

  @override
  VpnTunnelStatus get currentStatus => _status;

  @override
  String get lastStageText => _stageText;

  @override
  Stream<String> get stageTextStream => _stageController.stream;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    AppLogger.i(
      'TUNNEL',
      'OpenVPN.initialize group=$iosGroupId ext=$iosProviderBundleId',
    );
    try {
      await _engine.initialize(
        groupIdentifier: iosGroupId,
        providerBundleIdentifier: iosProviderBundleId,
        localizedDescription: iosLocalizedDescription,
        lastStatus: (s) => AppLogger.d(
          'TUNNEL',
          'lastStatus duration=${s.duration} in=${s.byteIn} out=${s.byteOut}',
        ),
        lastStage: (stage) =>
            AppLogger.d('TUNNEL', 'lastStage=$stage'),
      );
      _initialized = true;
      AppLogger.i('TUNNEL', 'OpenVPN engine initialized');
    } catch (e, st) {
      AppLogger.e('TUNNEL', 'OpenVPN.initialize failed', e, st);
      rethrow;
    }
  }

  void _onEngineStatus(VpnStatus? s) {
    if (s == null) return;
    AppLogger.d(
      'TUNNEL',
      'engine status duration=${s.duration} in=${s.byteIn} out=${s.byteOut}',
    );
  }

  /// Human text for the UI detail line + telemetry.
  static String stageText(VPNStage stage, String rawStage) {
    switch (stage) {
      case VPNStage.connected:
        return 'Connected';
      case VPNStage.denied:
        return 'Permission denied';
      case VPNStage.error:
        return 'Connection error ($rawStage)';
      case VPNStage.disconnected:
      case VPNStage.disconnecting:
      case VPNStage.exiting:
        return 'Disconnected';
      case VPNStage.prepare:
      case VPNStage.vpn_generate_config:
      case VPNStage.get_config:
        return 'Preparing…';
      case VPNStage.authenticating:
      case VPNStage.authentication:
        return 'Authenticating…';
      case VPNStage.resolve:
        return 'Resolving server…';
      case VPNStage.tcp_connect:
      case VPNStage.udp_connect:
      case VPNStage.connecting:
        return 'Contacting server…';
      case VPNStage.assign_ip:
        return 'Assigning IP…';
      case VPNStage.wait_connection:
        return 'Waiting for network…';
      default:
        return 'Working… ($rawStage)';
    }
  }

  void _onEngineStage(VPNStage stage, String rawStage) {
    _lastRawStage = rawStage;
    final mapped = _mapStage(stage);
    _stageText = stageText(stage, rawStage);
    final elapsed = _connectStartedAt == null
        ? ''
        : ' +${DateTime.now().difference(_connectStartedAt!).inSeconds}s';
    AppLogger.i('TUNNEL', 'engine stage=$stage raw=$rawStage → $mapped$elapsed');
    _emit(mapped);
    if (!_stageController.isClosed) _stageController.add(_stageText);

    // Resolve a pending connect() wait.
    final c = _connectCompleter;
    if (c != null && !c.isCompleted) {
      switch (stage) {
        case VPNStage.connected:
          c.complete();
          break;
        case VPNStage.denied:
          c.completeError(
            const VpnException(
              'permission-denied',
              'VPN permission denied. Allow the VPN request and try again.',
            ),
          );
          break;
        case VPNStage.error:
          c.completeError(
            VpnException(
              'connect-failed',
              'VPN connection failed ($rawStage). Try another server.',
            ),
          );
          break;
        case VPNStage.disconnected:
        case VPNStage.exiting:
          // The engine emits `disconnected` as its initial reset right after
          // connect() is called — ignore those for a 2s grace period so a
          // healthy handshake is never failed instantly. A later drop is real.
          final sinceStart = _connectStartedAt == null
              ? Duration.zero
              : DateTime.now().difference(_connectStartedAt!);
          if (sinceStart < const Duration(seconds: 2)) {
            AppLogger.d('TUNNEL', 'ignoring early $stage during grace period');
            break;
          }
          c.completeError(
            VpnException(
              'connect-failed',
              'VPN dropped during connect ($rawStage). Try another server.',
            ),
          );
          break;
        default:
          break; // still in progress
      }
    }
  }

  static VpnTunnelStatus _mapStage(VPNStage stage) {
    switch (stage) {
      case VPNStage.connected:
        return VpnTunnelStatus.connected;
      case VPNStage.denied:
      case VPNStage.disconnected:
      case VPNStage.disconnecting:
      case VPNStage.exiting:
        return VpnTunnelStatus.disconnected;
      case VPNStage.error:
        return VpnTunnelStatus.error;
      default:
        return VpnTunnelStatus.connecting;
    }
  }

  @override
  Future<void> connect(VpnServer server) async {
    AppLogger.i(
      'TUNNEL',
      'real connect → ${server.id} (${server.ip}) cfgLen=${server.openVpnConfig.length}',
    );
    if (kIsWeb) {
      throw const VpnException(
        'unsupported',
        'Real VPN is only available on Android/iOS.',
      );
    }
    final rawConfig = server.decodedOpenVpnConfig;
    if (!server.isVpnGate || rawConfig.isEmpty) {
      AppLogger.w('TUNNEL', 'no usable OpenVPN config for ${server.id}');
      throw const VpnException(
        'bad-config',
        'This server has no OpenVPN config. Pick a live VPNGate relay.',
      );
    }

    await _ensureInitialized();

    // Android VPN consent. connect() also triggers it, but an explicit
    // request gives a clearer denied log.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final granted = await _engine.requestPermissionAndroid();
        AppLogger.i('TUNNEL', 'android VPN permission granted=$granted');
        if (!granted) {
          throw const VpnException(
            'permission-denied',
            'VPN permission denied. Allow the VPN request and try again.',
          );
        }
      } catch (e) {
        if (e is VpnException) rethrow;
        AppLogger.w('TUNNEL', 'permission request threw, continuing anyway: $e');
      }
    }

    // Many `remote` lines cause ANR on some devices, so keep one. The
    // plugin's static filteredConfig() throws RangeError when the config has
    // exactly one remote (Random().nextInt(remotes.length - 1) == nextInt(0)),
    // so do it locally and only when there is something to collapse.
    final config = _singleRemoteConfig(rawConfig);

    _emit(VpnTunnelStatus.connecting);
    _stageText = 'Preparing…';
    if (!_stageController.isClosed) _stageController.add(_stageText);
    _connectCompleter = Completer<void>();
    _connectStartedAt = DateTime.now();
    _cancelRequested = false;

    // CRITICAL: on Android this Future only completes when the tunnel
    // STOPS (it wraps the native VpnService lifecycle) — it never completes
    // on success. Awaiting it with a timeout makes every working connection
    // look like a failure ~15s in. Fire it and watch the stage callbacks.
    AppLogger.i('TUNNEL', 'engine.connect ${server.name} as $vpnUsername/***');
    try {
      unawaited(
        _engine
            .connect(
              config,
              server.name,
              username: vpnUsername,
              password: vpnPassword,
              certIsRequired: false,
            )
            .then(
              (_) => AppLogger.d('TUNNEL', 'engine.connect future completed'),
              onError: (Object e, StackTrace st) {
                AppLogger.e('TUNNEL', 'engine.connect future errored', e, st);
                final c = _connectCompleter;
                if (c != null && !c.isCompleted && !_cancelRequested) {
                  c.completeError(
                    VpnException(
                      'connect-failed',
                      'Could not start VPN: $e',
                      e,
                    ),
                  );
                }
              },
            ),
      );
    } catch (e, st) {
      // Synchronous throw (e.g. "OpenVPN need to be initialized").
      AppLogger.e('TUNNEL', 'engine.connect threw synchronously', e, st);
      _teardown();
      _emit(VpnTunnelStatus.error);
      throw VpnException('connect-failed', 'Could not start VPN: $e', e);
    }
    _startPolling();

    AppLogger.d(
      'TUNNEL',
      'waiting up to ${connectTimeout.inSeconds}s for connected stage…',
    );
    try {
      await _connectCompleter!.future.timeout(connectTimeout);
      if (_cancelRequested) {
        AppLogger.i('TUNNEL', 'connect cancelled while waiting');
        throw const VpnException('cancelled', 'Connection cancelled.');
      }
      AppLogger.i('TUNNEL', 'real VPN connected ${server.id}');
    } on TimeoutException catch (e) {
      String last = _lastRawStage;
      try {
        last = (await _engine.stage().timeout(const Duration(seconds: 3)))
            .name;
      } catch (_) {}
      AppLogger.e(
        'TUNNEL',
        'connect timed out after $connectTimeout (last stage=$last)',
        e,
      );
      _teardown();
      _emit(VpnTunnelStatus.error);
      throw VpnException(
        'timeout',
        'Stuck at "$last" — this relay is too slow. Try another server.',
        e,
      );
    } finally {
      _stopPolling();
      _connectCompleter = null;
    }
  }

  /// Always stop the native tunnel before declaring failure — otherwise the
  /// OS keeps routing traffic while the UI says "not connected".
  void _teardown() {
    _stopPolling();
    try {
      _engine.disconnect();
    } catch (e) {
      AppLogger.w('TUNNEL', 'teardown disconnect threw: $e');
    }
    _connectCompleter = null;
  }

  /// Collapse a config to a single `remote` line.
  ///
  /// The plugin's `OpenVPN.filteredConfig` picks a random remote via
  /// `Random().nextInt(remotes.length - 1)`, which throws RangeError for a
  /// single-remote config. Returns the input unchanged when there is 0 or 1
  /// remote. When several exist, keep the first: VPNGate lists them in
  /// server-preference order, so it is the relay's own best candidate.
  static String _singleRemoteConfig(String config) {
    final lines = config.split('\n');
    final remoteIndexes = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim().toLowerCase();
      if (t.startsWith('remote ') || t.startsWith('remote-random ')) {
        remoteIndexes.add(i);
      }
    }
    if (remoteIndexes.length <= 1) {
      AppLogger.d('TUNNEL', 'config has ${remoteIndexes.length} remote(s) — unchanged');
      return config;
    }
    final keep = remoteIndexes.first;
    final filtered = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (remoteIndexes.contains(i) && i != keep) continue;
      filtered.add(lines[i]);
    }
    final out = filtered.join('\n');
    AppLogger.d(
      'TUNNEL',
      'collapsed ${remoteIndexes.length} remotes → 1 '
      '(${config.length} → ${out.length} chars)',
    );
    return out;
  }

  /// Safety net: if a stage callback is ever missed (activity-result /
  /// permission edge cases), poll the engine so the UI + completer still
  /// advance instead of freezing on "Connecting…".
  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final c = _connectCompleter;
      if (c == null || c.isCompleted) return;
      try {
        final stage =
            await _engine.stage().timeout(const Duration(seconds: 4));
        final elapsed = _connectStartedAt == null
            ? '?'
            : '${DateTime.now().difference(_connectStartedAt!).inSeconds}s';
        AppLogger.d('TUNNEL', 'poll stage=$stage (elapsed $elapsed)');
        if (stage == VPNStage.connected ||
            stage == VPNStage.error ||
            stage == VPNStage.denied ||
            stage == VPNStage.disconnected ||
            stage == VPNStage.exiting) {
          _onEngineStage(stage, 'poll:$stage');
        } else {
          // Refresh the detail line even when the mapped status is unchanged.
          _stageText = stageText(stage, 'poll:$stage');
          if (!_stageController.isClosed) _stageController.add(_stageText);
        }
      } catch (e) {
        AppLogger.w('TUNNEL', 'poll failed: $e');
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Future<void> disconnect() async {
    AppLogger.i('TUNNEL', 'real disconnect (was $_status, last=$_lastRawStage)');
    _stopPolling();
    // Release a pending connect() immediately so the UI can leave
    // "Connecting…" the moment the user taps cancel. Completing with an
    // error here used to surface as an unhandled async error (reported as a
    // crash), so signal via a flag and let connect() decide.
    _cancelRequested = true;
    final c = _connectCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    _connectCompleter = null;
    _stageText = '';
    if (!_stageController.isClosed) _stageController.add(_stageText);
    try {
      _engine.disconnect();
    } catch (e, st) {
      AppLogger.e('TUNNEL', 'engine.disconnect threw', e, st);
    }
    _emit(VpnTunnelStatus.disconnected);
  }

  void _emit(VpnTunnelStatus status) {
    if (_status == status && status != VpnTunnelStatus.error) return;
    AppLogger.d('TUNNEL', 'status $_status → $status');
    _status = status;
    if (!_controller.isClosed) _controller.add(status);
  }
}
