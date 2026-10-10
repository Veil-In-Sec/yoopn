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

    // Warm heavy Lottie compositions (auth screens) in a background isolate
    // while the splash animation plays — parallel, never on the critical path.
    LottieWarmup.warmup();

    // Logo animation window only (was 800ms). Session restore already
    // completed during Supabase.initialize in main(), so no need to idle.
    await Future.delayed(const Duration(milliseconds: 300));

    // Check if user session is present in Supabase
    Session? session = _supabaseClient.auth.currentSession;
    AppLogger.d('SPLASH', 'first session check: ${session != null ? 'found user=${session.user.email}' : 'null'}');

    if (session == null) {
      // One short retry for a token refresh landing just after init (was
      // 600ms). The AuthBloc session listener on the splash screen is the
      // backstop: it routes to home even if this check races.
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
