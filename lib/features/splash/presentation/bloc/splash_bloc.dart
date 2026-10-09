import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/core/utils/internet_connections.dart';

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
    emit(state.copyWith(status: SplashStatus.loading));

    await Future.delayed(const Duration(milliseconds: 800));

    // Check if user session is present in Supabase
    Session? session = _supabaseClient.auth.currentSession;

    // If session is still null, wait briefly for local storage session restoration
    if (session == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      session = _supabaseClient.auth.currentSession;
    }

    if (session != null) {
      emit(state.copyWith(status: SplashStatus.authenticated));
      return;
    }

    final isConnected = await InternetUtils.isConnected();
    if (!isConnected) {
      emit(state.copyWith(
        status: SplashStatus.error,
        errorMsg: "Please connect to the internet!",
      ));
      return;
    }

    emit(state.copyWith(status: SplashStatus.unauthenticated));
  }
}
