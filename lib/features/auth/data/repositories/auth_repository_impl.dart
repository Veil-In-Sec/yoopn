import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_credentials_model.dart';
import '../models/auth_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AuthUserEntity?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    AppLogger.d('AUTH', 'repo.signInWithPassword email=${AppLogger.maskEmail(email)}');
    final model = await remoteDataSource.signInWithPassword(
      AuthCredentialsModel(email: email, password: password),
    );
    AppLogger.d('AUTH', 'repo.signInWithPassword → ${model == null ? 'null' : model.email}');
    return model?.toEntity();
  }

  @override
  Future<AuthUserEntity?> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    AppLogger.d('AUTH', 'repo.signUpWithPassword email=${AppLogger.maskEmail(email)}');
    final model = await remoteDataSource.signUpWithPassword(
      AuthCredentialsModel(email: email, password: password),
    );
    AppLogger.d('AUTH', 'repo.signUpWithPassword → ${model == null ? 'null (confirm-email?)' : model.email}');
    return model?.toEntity();
  }

  @override
  Future<bool> signInWithGoogle() async {
    AppLogger.d('AUTH', 'repo.signInWithGoogle');
    final ok = await remoteDataSource.signInWithGoogle();
    AppLogger.d('AUTH', 'repo.signInWithGoogle → $ok');
    return ok;
  }

  @override
  Future<void> signInWithOtp({required String email}) async {
    AppLogger.d('AUTH', 'repo.signInWithOtp email=${AppLogger.maskEmail(email)}');
    await remoteDataSource.signInWithOtp(email);
  }

  @override
  Future<AuthUserEntity?> verifyOtp({
    required String email,
    required String otp,
  }) async {
    AppLogger.d('AUTH', 'repo.verifyOtp email=${AppLogger.maskEmail(email)}');
    final model = await remoteDataSource.verifyOtp(email, otp);
    AppLogger.d('AUTH', 'repo.verifyOtp → ${model == null ? 'null' : 'ok'}');
    return model?.toEntity();
  }

  @override
  Future<AuthUserEntity?> updateEmail({required String email}) async {
    AppLogger.d('AUTH', 'repo.updateEmail email=${AppLogger.maskEmail(email)}');
    final model = await remoteDataSource.updateEmail(email);
    return model?.toEntity();
  }

  @override
  Future<AuthUserEntity?> updatePassword({required String password}) async {
    AppLogger.d('AUTH', 'repo.updatePassword');
    final model = await remoteDataSource.updatePassword(password);
    return model?.toEntity();
  }

  @override
  Future<AuthUserEntity?> updateDisplayName({
    required String displayName,
  }) async {
    AppLogger.d('AUTH', 'repo.updateDisplayName');
    final model = await remoteDataSource.updateDisplayName(displayName);
    return model?.toEntity();
  }

  @override
  Future<void> signOut() async {
    AppLogger.i('AUTH', 'repo.signOut');
    await remoteDataSource.signOut();
  }

  @override
  AuthUserEntity mapSessionUser(Session session) =>
      AuthUserModel.fromSupabaseUser(session.user).toEntity();

  @override
  Session? get currentSession => remoteDataSource.currentSession;

  @override
  Stream<AuthState> get onAuthStateChange => remoteDataSource.onAuthStateChange;
}
