import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/data/tunnel/vpn_tunnel.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

class OpenVpnTunnel implements VpnTunnel {
  OpenVpnTunnel({this.connectTimeout = const Duration(seconds: 30)}) {
    _engine = OpenVPN(
      onVpnStatusChanged: _onEngineStatus,
      onVpnStageChanged: _onEngineStage,
    );
    AppLogger.d('TUNNEL', 'OpenVpnTunnel created (real, openvpn_flutter)');
  }

  static const vpnUsername = 'vpn';
  static const vpnPassword = 'vpn';

  static const iosGroupId = 'group.com.vis.yoopn.vpn';
  static const iosProviderBundleId = 'com.vis.yoopn.VPNExtension';
  static const iosLocalizedDescription = 'YooPN';

  final Duration connectTimeout;

  late final OpenVPN _engine;
  final _controller = StreamController<VpnTunnelStatus>.broadcast();
  final _stageController = StreamController<String>.broadcast();
  VpnTunnelStatus _status = VpnTunnelStatus.disconnected;
  bool _initialized = false;
  Future<void>? _initInflight;
  bool _connectActive = false;
  int _generation = 0;
  Completer<void>? _connectCompleter;
  String _lastRawStage = '';
  String _stageText = '';
  String? _lastStatusIn;
  String? _lastStatusOut;
  DateTime? _lastStatusLogAt;
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

  Future<void> _ensureInitialized() {
    if (_initialized) return Future.value();
    final inflight = _initInflight;
    if (inflight != null) return inflight;
    final future = _doInitialize();
    _initInflight = future;
    future.then((_) {}, onError: (_) {
      if (identical(_initInflight, future)) _initInflight = null;
    });
    return future;
  }

  Future<void> _doInitialize() async {
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
      throw VpnException(
        'init-failed',
        'Could not start the VPN engine: $e',
        e,
      );
    }
  }

  void _onEngineStatus(VpnStatus? s) {
    if (s == null) return;
    final now = DateTime.now();
    final moved = s.byteIn != _lastStatusIn || s.byteOut != _lastStatusOut;
    final lastAt = _lastStatusLogAt;
    final freshEnough =
        lastAt != null && now.difference(lastAt).inSeconds < 5;
    final stale =
        lastAt == null || now.difference(lastAt).inSeconds >= 30;
    if (freshEnough || (!moved && !stale)) return;
    _lastStatusIn = s.byteIn;
    _lastStatusOut = s.byteOut;
    _lastStatusLogAt = now;
    AppLogger.d(
      'TUNNEL',
      'engine status duration=${s.duration} in=${s.byteIn} out=${s.byteOut}',
    );
  }

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
        final lower = rawStage.toLowerCase();
        if (lower.contains('auth_fail')) {
          return 'Login rejected…';
        }
        if (lower.contains('noprocess')) {
          return 'Disconnected';
        }
        if (lower.contains('reconnect')) {
          return 'Retrying…';
        }
        if (lower.contains('add_routes')) {
          return 'Setting up routes…';
        }
        if (lower.contains('nonetwork') || lower.contains('no network')) {
          return 'Waiting for network…';
        }
        return 'Working… ($rawStage)';
    }
  }

  void _onEngineStage(VPNStage stage, String rawStage) {
    _lastRawStage = rawStage;
    final rawLower = rawStage.toLowerCase();
    final effectiveStage =
        stage == VPNStage.unknown && rawLower.contains('no_connection')
            ? VPNStage.disconnected
            : stage;
    final authRejected = rawLower.contains('auth_fail');
    final isIdleSignal = rawLower.contains('noprocess');
    var mapped = _mapStage(effectiveStage);
    if (stage == VPNStage.unknown && authRejected) {
      mapped = VpnTunnelStatus.error;
    }
    if (isIdleSignal) {
      mapped = VpnTunnelStatus.disconnected;
    }
    _stageText = stageText(effectiveStage, rawStage);
    final elapsed = _connectStartedAt == null
        ? ''
        : ' +${DateTime.now().difference(_connectStartedAt!).inSeconds}s';
    AppLogger.i('TUNNEL', 'engine stage=$stage raw=$rawStage → $mapped$elapsed');
    _emit(mapped);
    if (!_stageController.isClosed) _stageController.add(_stageText);

    final c = _connectCompleter;
    if (c != null && !c.isCompleted) {
      if (stage == VPNStage.unknown && authRejected) {
        c.completeError(
          const VpnException(
            'auth-rejected',
            'This relay rejected the login (it may be full or offline). Try another server.',
          ),
        );
      } else if (isIdleSignal) {
        AppLogger.d('TUNNEL', 'ignoring idle noprocess signal');
      } else {
        final displayRaw = rawStage.startsWith('poll:')
            ? rawStage.substring(5)
            : rawStage;
        switch (effectiveStage) {
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
                'VPN connection failed ($displayRaw). Try another server.',
              ),
            );
            break;
          case VPNStage.disconnected:
          case VPNStage.exiting:
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
                'VPN dropped during connect ($displayRaw). Try another server.',
              ),
            );
            break;
          default:
            break;
        }
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

    final candidates = _remoteVariants(rawConfig);
    AppLogger.i(
      'TUNNEL',
      '${candidates.length} route(s) to try for ${server.id}',
    );

    if (_connectActive) {
      throw const VpnException(
        'busy',
        'A connection attempt is already running. Please wait.',
      );
    }
    _connectActive = true;
    _generation++;
    try {
      _cancelRequested = false;
      VpnException? lastError;
    for (var i = 0; i < candidates.length; i++) {
      if (i > 0) {
        if (_cancelRequested) break;
        _setStage('Trying next route… (${i + 1}/${candidates.length})');
      }
      try {
        await _attemptConnect(
          server,
          candidates[i],
          _perAttemptTimeout(candidates.length),
        );
        AppLogger.i(
          'TUNNEL',
          'real VPN connected ${server.id} '
          'via route ${i + 1}/${candidates.length}',
        );
        return;
      } on VpnException catch (e) {
        if (e.code == 'cancelled' || e.code == 'permission-denied') rethrow;
        lastError = e;
        AppLogger.w(
          'TUNNEL',
          'route ${i + 1}/${candidates.length} failed: $e',
        );
        _teardown();
        if (_cancelRequested) {
          throw const VpnException('cancelled', 'Connection cancelled.');
        }
      }
    }
      throw lastError ??
          const VpnException(
            'connect-failed',
            'Could not connect. Try another server.',
          );
    } finally {
      _connectActive = false;
    }
  }

  Duration _perAttemptTimeout(int routes) {
    if (routes <= 1) return connectTimeout;
    final per = connectTimeout.inSeconds ~/ routes;
    return Duration(seconds: per < 8 ? 8 : per);
  }

  void _setStage(String text) {
    _stageText = text;
    if (!_stageController.isClosed) _stageController.add(text);
  }

  Future<void> _attemptConnect(
    VpnServer server,
    String config,
    Duration timeout,
  ) async {
    _emit(VpnTunnelStatus.connecting);
    _setStage('Preparing…');
    _connectCompleter = Completer<void>();
    _connectStartedAt = DateTime.now();

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
      AppLogger.e('TUNNEL', 'engine.connect threw synchronously', e, st);
      _teardown();
      _emit(VpnTunnelStatus.error);
      throw VpnException('connect-failed', 'Could not start VPN: $e', e);
    }
    _startPolling();

    AppLogger.d(
      'TUNNEL',
      'waiting up to ${timeout.inSeconds}s for connected stage…',
    );
    try {
      await _connectCompleter!.future.timeout(timeout);
      if (_cancelRequested) {
        AppLogger.i('TUNNEL', 'connect cancelled while waiting');
        throw const VpnException('cancelled', 'Connection cancelled.');
      }
    } on TimeoutException catch (e) {
      String last = _lastRawStage;
      try {
        last = (await _engine.stage().timeout(const Duration(seconds: 3)))
            .name;
      } catch (_) {}
      AppLogger.e(
        'TUNNEL',
        'connect timed out after $timeout (last stage=$last)',
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

  void _teardown() {
    _stopPolling();
    try {
      _engine.disconnect();
    } catch (e) {
      AppLogger.w('TUNNEL', 'teardown disconnect threw: $e');
    }
    _connectCompleter = null;
  }

  static List<String> _remoteVariants(String config) {
    final lines = config.split('\n');
    final remoteIndexes = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_isRemoteLine(lines[i])) remoteIndexes.add(i);
    }
    if (remoteIndexes.length <= 1) {
      AppLogger.d(
        'TUNNEL',
        'config has ${remoteIndexes.length} remote(s) — unchanged',
      );
      return [config];
    }
    final base = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (remoteIndexes.contains(i)) continue;
      if (lines[i].trim().toLowerCase().startsWith('remote-random')) continue;
      base.add(lines[i]);
    }
    final remotes = remoteIndexes.map((i) => lines[i]).toList()
      ..sort((a, b) => _remoteScore(a).compareTo(_remoteScore(b)));
    final insertAt = remoteIndexes.first.clamp(0, base.length);
    AppLogger.d(
      'TUNNEL',
      'split ${remoteIndexes.length} remotes into variants '
      '(tcp/443 first)',
    );
    return remotes.map((r) {
      final out = List<String>.from(base)..insert(insertAt, r);
      return out.join('\n');
    }).toList();
  }

  static bool _isRemoteLine(String line) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#') || t.startsWith(';')) return false;
    final lower = t.toLowerCase();
    if (!lower.startsWith('remote ')) return false;
    if (lower.startsWith('remote-random')) return false;
    return t.split(RegExp(r'\s+')).length >= 2;
  }

  static int _remoteScore(String remoteLine) {
    final parts = remoteLine.trim().split(RegExp(r'\s+'));
    var score = 10;
    for (var k = 2; k < parts.length; k++) {
      final p = parts[k].toLowerCase();
      if (p == 'tcp' || p == 'tcp-client') return 0;
      if (p == 'udp') score = 5;
    }
    final port = parts.length > 2 ? int.tryParse(parts[2]) : null;
    if (port == 443 && score > 1) score = 1;
    return score;
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final c = _connectCompleter;
      if (c == null || c.isCompleted) return;
      final gen = _generation;
      try {
        final stage =
            await _engine.stage().timeout(const Duration(seconds: 4));
        // Tick started before a disconnect/reconnect: stale, ignore so it
        // can never resurrect status after disconnect().
        if (gen != _generation || _cancelRequested) return;
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
    _cancelRequested = true;
    _generation++;
    final c = _connectCompleter;
    if (c != null && !c.isCompleted) {
      // Error, not success: waiters must observe cancellation, never a
      // phantom connect-ok.
      c.completeError(const VpnException('cancelled', 'Connection cancelled.'));
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

  @override
  Future<bool> syncState() async {
    AppLogger.i('TUNNEL', 'syncState — asking engine for the truth');
    try {
      await _ensureInitialized();
    } catch (e) {
      AppLogger.w('TUNNEL', 'syncState init failed, staying disconnected', e);
      return false;
    }
    VPNStage stage;
    try {
      stage = await _engine.stage().timeout(const Duration(seconds: 4));
    } catch (e) {
      AppLogger.w('TUNNEL', 'syncState stage read failed: $e');
      return false;
    }
    if (stage == VPNStage.connected) {
      AppLogger.i('TUNNEL', 'syncState → engine is CONNECTED, adopting');
      _setStage('Connected');
      _emit(VpnTunnelStatus.connected);
      return true;
    }
    if (_needsCleanup(stage, '')) {
      AppLogger.i('TUNNEL', 'syncState → stopping orphaned $stage');
      try {
        _engine.disconnect();
      } catch (e) {
        AppLogger.w('TUNNEL', 'syncState cleanup disconnect threw: $e');
      }
    } else {
      AppLogger.i('TUNNEL', 'syncState → engine is $stage, nothing to stop');
    }
    _emit(VpnTunnelStatus.disconnected);
    return false;
  }

  static bool _needsCleanup(VPNStage stage, String rawLower) {
    switch (stage) {
      case VPNStage.connected:
      case VPNStage.disconnected:
      case VPNStage.disconnecting:
      case VPNStage.exiting:
      case VPNStage.denied:
      case VPNStage.error:
        return false;
      case VPNStage.unknown:
        return rawLower.contains('reconnect') ||
            rawLower.contains('add_routes');
      default:
        return true;
    }
  }

  void _emit(VpnTunnelStatus status) {
    if (_status == status && status != VpnTunnelStatus.error) return;
    AppLogger.d('TUNNEL', 'status $_status → $status');
    _status = status;
    if (!_controller.isClosed) _controller.add(status);
  }
}
