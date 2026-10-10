import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/core/utils/app_logger.dart';

/// Global observer — logs EVERY Bloc/Cubit lifecycle point automatically.
///
/// Covers: SplashBloc, AuthBloc, VpnBloc.
/// Register once in `main()`: `Bloc.observer = AppBlocObserver();`
class AppBlocObserver extends BlocObserver {
  String _short(Object? value) => AppLogger.short(value, 300);

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    AppLogger.i('BLOC', 'created ${bloc.runtimeType} | state=${_short(bloc.state)}');
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    AppLogger.d('BLOC', '${bloc.runtimeType} ◀ event=${_short(event)}');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    AppLogger.d(
      'BLOC',
      '${bloc.runtimeType} Δ ${_short(change.currentState)} → ${_short(change.nextState)}',
    );
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    AppLogger.i(
      'BLOC',
      '${bloc.runtimeType} ${transition.event.runtimeType} ⇒ ${_short(transition.nextState)}',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    AppLogger.e('BLOC', '${bloc.runtimeType} error', error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    AppLogger.i('BLOC', 'closed ${bloc.runtimeType}');
  }
}
