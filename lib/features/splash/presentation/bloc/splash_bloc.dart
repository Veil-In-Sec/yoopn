import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/core/utils/lottie_warmup.dart';

part 'splash_event.dart';
part 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  final SupabaseClient _supabaseClient;

  SplashBloc({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client,
        super(const SplashState()) {
    on<AppStarted>(_onAppStarted);
  }

  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<SplashState> emit,
  ) async {
    AppLogger.i('SPLASH', 'AppStarted → checking session');
    emit(state.copyWith(status: SplashStatus.loading));

    LottieWarmup.warmup();

    await Future.delayed(const Duration(milliseconds: 300));

    Session? session = _supabaseClient.auth.currentSession;
    AppLogger.d('SPLASH', 'first session check: ${session != null ? 'found user=${session.user.email}' : 'null'}');

    if (session == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      session = _supabaseClient.auth.currentSession;
      AppLogger.d('SPLASH', 'retry session check: ${session != null ? 'found' : 'still null'}');
    }

    if (session != null) {
      AppLogger.i('SPLASH', 'authenticated → home (${session.user.email})');
      emit(state.copyWith(status: SplashStatus.authenticated));
    } else {
      AppLogger.i('SPLASH', 'unauthenticated → auth screen');
      emit(state.copyWith(status: SplashStatus.unauthenticated));
    }
  }
}
