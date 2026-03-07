import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import 'features/auth/data/datasources/auth_local_data_source_impl.dart';
import 'features/auth/data/datasources/auth_remote_data_source_impl.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/i_auth_repository.dart';
import 'features/auth/domain/usecases/get_current_user_use_case.dart';
import 'features/auth/domain/usecases/login_use_case.dart';
import 'features/auth/domain/usecases/logout_use_case.dart';
import 'features/auth/domain/usecases/refresh_token_use_case.dart';
import 'features/auth/domain/usecases/register_use_case.dart';
import 'features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'features/auth/presentation/bloc/register/register_cubit.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// File-level initialisation flag.
///
/// A boolean variable at the module level is the only reliable idempotence
/// guard for [initDependencies].
///
/// The alternative `sl.isRegistered<Dio>()` is unsafe: the `injectable`
/// build-runner generator may produce a configuration file that registers
/// [Dio] before [initDependencies] is called, which would cause the guard
/// to return early and leave every use case unregistered.
///
/// This flag lives in the Dart isolate, which integration tests share for
/// the lifetime of the test process. [initDependencies] is therefore called
/// exactly once regardless of how many tests are executed.
bool _initialized = false;

/// Registers all dependencies in the service locator.
///
/// Call once from [main] before [runApp]. Dependencies are registered in
/// bottom-up layer order: infrastructure → data → domain → presentation.
///
/// All registrations use [registerLazySingleton] (instantiated on first access)
/// except [AuthBloc] and [RegisterCubit], which are registered as factories
/// (new instance per call) because BLoC/Cubit instances must not be shared
/// across widget subtrees — each [BlocProvider] creates its own instance.
Future<void> initDependencies() async {
  if (_initialized) return;
  _initialized = true;

  // ── Infrastructure ──────────────────────────────────────────────────────────

  // Dio HTTP client — single instance with global /api prefix and JSON headers.
  sl.registerLazySingleton<Dio>(() {
    return Dio(
      BaseOptions(
        // Android emulator: 10.0.2.2 routes to the host machine's localhost.
        // Override at build time with --dart-define=API_BASE_URL=<url>.
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:3000/api',
        ),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  });

  // flutter_secure_storage — encrypted token vault.
  //
  // AndroidOptions() defaults (flutter_secure_storage v10+):
  //   keyCipherAlgorithm     : RSA_ECB_OAEPwithSHA_256andMGF1Padding
  //   storageCipherAlgorithm : AES_GCM_NoPadding
  //   migrateOnAlgorithmChange: true  ← auto-migrates legacy encrypted data.
  sl.registerLazySingleton<FlutterSecureStorage>(
        () => const FlutterSecureStorage(
      aOptions: AndroidOptions(),
    ),
  );

  // ── Data layer ──────────────────────────────────────────────────────────────

  sl.registerLazySingleton<AuthRemoteDataSourceImpl>(
        () => AuthRemoteDataSourceImpl(dio: sl<Dio>()),
  );

  sl.registerLazySingleton<AuthLocalDataSourceImpl>(
        () => AuthLocalDataSourceImpl(
      secureStorage: sl<FlutterSecureStorage>(),
    ),
  );

  sl.registerLazySingleton<IAuthRepository>(
        () => AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSourceImpl>(),
      localDataSource: sl<AuthLocalDataSourceImpl>(),
    ),
  );

  // ── Domain layer ─────────────────────────────────────────────────────────────

  sl.registerLazySingleton(() => LoginUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton(() => LogoutUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton(
        () => GetCurrentUserUseCase(sl<IAuthRepository>()),
  );
  sl.registerLazySingleton(
        () => RefreshTokenUseCase(sl<IAuthRepository>()),
  );
  sl.registerLazySingleton(() => RegisterUseCase(sl<IAuthRepository>()));

  // ── Presentation layer ───────────────────────────────────────────────────────

  // Factory — each [BlocProvider.create] callback receives a fresh instance.
  sl.registerFactory<AuthBloc>(
        () => AuthBloc(
      loginUseCase: sl<LoginUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
      getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
      refreshTokenUseCase: sl<RefreshTokenUseCase>(),
    ),
  );

  sl.registerFactory<RegisterCubit>(
        () => RegisterCubit(registerUseCase: sl<RegisterUseCase>()),
  );
}