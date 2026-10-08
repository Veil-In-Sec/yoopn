import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/core/utils/internet_connections.dart';

part 'splash_event.dart';
part 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc() : super(const SplashState()) {
    on<AppStarted>(_onAppStarted);
    // on<AppCrashed>(_onAppCrashed);
  }

  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<SplashState> emit,
  ) async {
    emit(state.copyWith(status: SplashStatus.loading));

    await Future.delayed(const Duration(seconds: 4));
    if (await InternetUtils.isConnected()) {
      emit(state.copyWith(status: SplashStatus.loaded));
    } else {
      emit(state.copyWith(status: SplashStatus.error, errorMsg: "Please connect to internet!"));
    }
  }

  // Future<void> _onAppCrashed(
  //   AppCrashed event,
  //   Emitter<SplashState> emit,
  // ) async {
  //   emit(
  //     state.copyWith(status: SplashStatus.error, errorMsg: event.toString()),
  //   );
  // }
}
