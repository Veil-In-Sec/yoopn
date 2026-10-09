// ignore_for_file: non_constant_identifier_names

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/features/dashboard/data/datasources/speed_test_data_source.dart';
import 'package:yoopn/features/dashboard/data/datasources/vpn_data_source.dart';
import 'package:yoopn/features/dashboard/data/datasources/vpn_gate_remote_data_source.dart';
import 'package:yoopn/features/dashboard/data/datasources/vpn_local_data_source.dart';
import 'package:yoopn/features/dashboard/data/repositories/vpn_repository_impl.dart';
import 'package:yoopn/features/dashboard/data/tunnel/vpn_tunnel.dart';
import 'package:yoopn/features/dashboard/domain/repositories/vpn_repository.dart';
import 'package:yoopn/features/dashboard/domain/usecases/dashboard_use_cases.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/speed_test_cubit.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
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
  sl.registerLazySingleton<Dio>(
    () => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        responseType: ResponseType.plain,
      ),
    ),
  );
  // Swappable tunnel: simulated everywhere for now. Drop in the native
  // OpenVPN VpnTunnel for Android/iOS here — bloc/UI stay untouched.
  sl.registerLazySingleton<VpnTunnel>(() => SimulatedVpnTunnel());
  sl.registerLazySingleton<VpnDataSource>(
    () => TunnelVpnDataSource(tunnel: sl<VpnTunnel>()),
  );
  sl.registerLazySingleton<VpnGateRemoteDataSource>(
    () => VpnGateRemoteDataSourceImpl(dio: sl<Dio>()),
  );
  sl.registerLazySingleton<VpnLocalDataSource>(() {
    // sqflite has no Windows/Web support; use the in-memory stand-in there
    // so desktop runs and widget tests keep working.
    if (kIsWeb) return InMemoryVpnLocalDataSource();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return SqfliteVpnLocalDataSource();
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return InMemoryVpnLocalDataSource();
    }
  });
  sl.registerLazySingleton<VpnRepository>(
    () => VpnRepositoryImpl(
      connectionDataSource: sl<VpnDataSource>(),
      gateDataSource: sl<VpnGateRemoteDataSource>(),
      localDataSource: sl<VpnLocalDataSource>(),
    ),
  );
  sl.registerFactory<DashboardUseCases>(
    () => DashboardUseCases.fromRepository(sl<VpnRepository>()),
  );
  sl.registerFactory<VpnBloc>(() => VpnBloc(useCases: sl<DashboardUseCases>()));
  sl.registerLazySingleton<SpeedTestDataSource>(
    () => LiveSpeedTestDataSource(dio: sl<Dio>()),
  );
  sl.registerFactory<SpeedTestCubit>(
    () => SpeedTestCubit(dataSource: sl<SpeedTestDataSource>()),
  );
}
