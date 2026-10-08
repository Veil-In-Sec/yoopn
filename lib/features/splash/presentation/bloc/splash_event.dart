part of 'splash_bloc.dart';

sealed class SplashEvent extends Equatable {
  const SplashEvent();
}

class AppStarted extends SplashEvent {
  const AppStarted();
  @override
  List<Object?> get props => [];
}

class AppCrashed extends SplashEvent {
  const AppCrashed();
  @override
  List<Object?> get props => [];
}
