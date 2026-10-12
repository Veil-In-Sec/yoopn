import 'package:flutter/material.dart';
import 'package:yoopn/core/telemetry/supabase_telemetry.dart';
import 'package:yoopn/core/utils/app_logger.dart';

class TelemetryNavigatorObserver extends NavigatorObserver {
  String? _current;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _track(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _track(newRoute);
  }

  void _track(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name == _current) return;
    _current = name;
    AppLogger.d('ROUTE', 'screen=$name');
    Telemetry.screen(name);
  }
}