import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_credentials_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AuthUserEntity?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final model = await remoteDataSource.signInWithPassword(
      AuthCredentialsModel(email: email, password: password),
    );
    return model?.toEntity();
  }

  @override
  Future<AuthUserEntity?> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    final model = await remoteDataSource.signUpWithPassword(
      AuthCredentialsModel(email: email, password: password),
    );
    return model?.toEntity();
  }

  @override
  Future<bool> signInWithGoogle() async {
    return await remoteDataSource.signInWithGoogle();
  }

  @override
  Future<void> signInWithOtp({required String email}) async {
    await remoteDataSource.signInWithOtp(email);
  }

  @override
  Future<AuthUserEntity?> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final model = await remoteDataSource.verifyOtp(email, otp);
    return model?.toEntity();
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  @override
  Session? get currentSession => remoteDataSource.currentSession;

  @override
  Stream<AuthState> get onAuthStateChange => remoteDataSource.onAuthStateChange;
}
