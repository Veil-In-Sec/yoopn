part of 'splash_bloc.dart';

enum SplashStatus { loading, authenticated, unauthenticated, error }

final class SplashState extends Equatable {
  final SplashStatus status;
  final String? errorMsg;

  const SplashState({this.status = SplashStatus.loading, this.errorMsg});

  SplashState copyWith({SplashStatus? status, String? errorMsg}) {
    return SplashState(
      status: status ?? this.status,
      errorMsg: errorMsg ?? this.errorMsg,
    );
  }

  @override
  List<Object?> get props => [status, errorMsg];
}
