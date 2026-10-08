import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
<<<<<<< HEAD
import 'package:yoopn/core/utils/internet_connections.dart';
=======
>>>>>>> 5a5552a99aee2e3f776e5e720b49ebac3b94f5ab

part 'splash_event.dart';
part 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc() : super(const SplashState()) {
    on<AppStarted>(_onAppStarted);
<<<<<<< HEAD
    // on<AppCrashed>(_onAppCrashed);
=======
    on<AppCrashed>(_onAppCrashed);
>>>>>>> 5a5552a99aee2e3f776e5e720b49ebac3b94f5ab
  }

  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<SplashState> emit,
  ) async {
    emit(state.copyWith(status: SplashStatus.loading));

    await Future.delayed(const Duration(seconds: 4));
<<<<<<< HEAD
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
=======

    emit(state.copyWith(status: SplashStatus.loaded));
  }

  Future<void> _onAppCrashed(
    AppCrashed event,
    Emitter<SplashState> emit,
  ) async {
    emit(
      state.copyWith(status: SplashStatus.error, errorMsg: event.toString()),
    );
  }
>>>>>>> 5a5552a99aee2e3f776e5e720b49ebac3b94f5ab
}
