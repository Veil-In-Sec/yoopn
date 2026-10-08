// ignore_for_file: non_constant_identifier_names

import 'package:get_it/get_it.dart';
<<<<<<< HEAD
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
=======
>>>>>>> 5a5552a99aee2e3f776e5e720b49ebac3b94f5ab
import 'package:yoopn/features/splash/presentation/bloc/splash_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> init_dependency_injection() async {
  _factory_registry();
}

Future<void> _factory_registry() async {
<<<<<<< HEAD
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerFactory<SplashBloc>(() => SplashBloc());
  sl.registerFactory<AuthBloc>(() => AuthBloc());
=======
  sl.registerFactory<SplashBloc>(() => SplashBloc());
>>>>>>> 5a5552a99aee2e3f776e5e720b49ebac3b94f5ab
}
