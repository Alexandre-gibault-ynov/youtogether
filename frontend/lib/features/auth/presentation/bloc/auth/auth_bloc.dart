import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/usecases/use_case.dart';
import '../../../domain/usecases/get_current_user_use_case.dart';
import '../../../domain/usecases/login_use_case.dart';
import '../../../domain/usecases/logout_use_case.dart';
import '../../../domain/usecases/refresh_token_use_case.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC responsible for managing authentication state across the application.
///
/// Receives [AuthEvent] inputs from the presentation layer and delegates to
/// the corresponding use case. Emits [AuthState] transitions that drive
/// navigation and UI rendering.
///
/// All use cases are injected via constructor to maintain testability and to
/// honour the Dependency Inversion Principle.
///
/// The BLoC never catches exceptions directly; all errors arrive as
/// [Left<Failure, T>] values from the use cases and are mapped to
/// [AuthState.failure].
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _refreshTokenUseCase = refreshTokenUseCase,
        super(const AuthState.initial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckStatusRequested>(_onCheckStatusRequested);
    on<AuthTokenRefreshRequested>(_onTokenRefreshRequested);
    on<AuthUserSessionEstablished>(_onUserSessionEstablished);
  }

  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;

  // ---------------------------------------------------------------------------
  // Login — email / password
  // ---------------------------------------------------------------------------

  Future<void> _onLoginRequested(
      AuthLoginRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(const AuthState.loading());

    final result = await _loginUseCase(
      LoginParams(email: event.email, password: event.password),
    );

    result.fold(
          (failure) => emit(AuthState.failure(failure: failure)),
          (user) => emit(AuthState.authenticated(user: user)),
    );
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  Future<void> _onLogoutRequested(
      AuthLogoutRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(const AuthState.loading());

    final result = await _logoutUseCase(const NoParams());

    result.fold(
          (failure) => emit(AuthState.failure(failure: failure)),
          (_) => emit(const AuthState.unauthenticated()),
    );
  }

  // ---------------------------------------------------------------------------
  // Check session status on cold start
  // ---------------------------------------------------------------------------

  Future<void> _onCheckStatusRequested(
      AuthCheckStatusRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(const AuthState.loading());

    final result = await _getCurrentUserUseCase(const NoParams());

    result.fold(
          (failure) => emit(const AuthState.unauthenticated()),
          (user) => user != null
          ? emit(AuthState.authenticated(user: user))
          : emit(const AuthState.unauthenticated()),
    );
  }

  // ---------------------------------------------------------------------------
  // Token refresh (internal — triggered by Dio 401 interceptor)
  // ---------------------------------------------------------------------------

  Future<void> _onTokenRefreshRequested(
      AuthTokenRefreshRequested event,
      Emitter<AuthState> emit,
      ) async {
    final result = await _refreshTokenUseCase(const NoParams());

    result.fold(
      // Refresh failed: force logout; the user must re-authenticate.
          (failure) => emit(const AuthState.unauthenticated()),
      // Refresh succeeded: no state transition; the interceptor retries the
      // original request transparently.
          (_) => null,
    );
  }

  // ---------------------------------------------------------------------------
  // Post-registration auto-login
  // ---------------------------------------------------------------------------

  /// Handles the auto-login that immediately follows a successful registration.
  ///
  /// The [RegisterPage] dispatches this event once [RegisterCubit] emits
  /// [RegisterState.success]. Tokens are already stored in secure storage by
  /// [AuthRepositoryImpl.register]; no additional network call is needed.
  void _onUserSessionEstablished(
      AuthUserSessionEstablished event,
      Emitter<AuthState> emit,
      ) {
    emit(AuthState.authenticated(user: event.user));
  }
}