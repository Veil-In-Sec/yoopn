// ignore_for_file: non_constant_identifier_names

import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:yoopn/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yoopn/features/auth/domain/repositories/auth_repository.dart';
import 'package:yoopn/features/auth/domain/usecases/auth_use_cases.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> init_dependency_injection() async {
  _factory_registry();
}

Future<void> _factory_registry() async {
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(supabaseClient: sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl<AuthRemoteDataSource>()),
  );
  sl.registerFactory<AuthUseCases>(
    () => AuthUseCases.fromRepository(sl<AuthRepository>()),
  );
  sl.registerFactory<SplashBloc>(
    () => SplashBloc(supabaseClient: sl<SupabaseClient>()),
  );
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      repository: sl<AuthRepository>(),
      useCases: sl<AuthUseCases>(),
    ),
  );
}
