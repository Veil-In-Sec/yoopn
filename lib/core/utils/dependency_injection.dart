// ignore_for_file: non_constant_identifier_names

import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> init_dependency_injection() async {
  _factory_registry();
}

Future<void> _factory_registry() async {
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerFactory<SplashBloc>(() => SplashBloc());
  sl.registerFactory<AuthBloc>(() => AuthBloc());
}
