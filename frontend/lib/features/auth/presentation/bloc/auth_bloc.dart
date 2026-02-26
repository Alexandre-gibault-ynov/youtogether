import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtogether/core/usecases/use_case.dart';
import 'package:youtogether/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:youtogether/features/auth/domain/usecases/login_use_case.dart';
import 'package:youtogether/features/auth/domain/usecases/logout_use_case.dart';
import 'package:youtogether/features/auth/domain/usecases/refresh_token_use_case.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_state.dart';

/// BLoC responsible for managing authentication state across the application.
///
/// Receives [AuthEvent] inputs from the presentation layer and delegates to
/// the corresponding use case.  Emits [AuthState] transitions that drive
/// navigation and UI rendering.
///
/// All use cases are injected via constructor to maintain testability and
/// to honour the Dependency Inversion Principle.
///
/// The BLoC never catches exceptions directly; all errors arrive as
/// [Left<Failure, T>] values from the use cases and are mapped to
/// [AuthState.failure].
class AuthBloc extends Bloc<AuthEvent, AuthState> {

  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
  }) : _loginUseCase = loginUseCase,
       _logoutUseCase = logoutUseCase,
       _getCurrentUserUseCase = getCurrentUserUseCase,
       _refreshTokenUseCase = refreshTokenUseCase,
       super(const AuthState.initial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckStatusRequested>(_onCheckStatusRequested);
    on<AuthTokenRefreshRequested>(_onRefreshTokenRequested);
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState.loading());

    final result = await _loginUseCase(
      LoginParams(email: event.email, password: event.password),
    );
    
    result.fold(
        (failure) => emit(AuthState.failure(failure: failure)),
        (user) => emit(AuthState.authenticated(user: user)),
    );
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState.loading());

    final result = await _logoutUseCase(const NoParams());

    result.fold(
        (failure) => emit(AuthState.failure(failure: failure)),
        (_) => emit(const AuthState.unauthenticated()),
    );
  }

  Future<void> _onCheckStatusRequested(AuthCheckStatusRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState.loading());
    
    final result = await _getCurrentUserUseCase(const NoParams());

    result.fold(
        (failure) => emit(AuthState.failure(failure: failure)),
        (user) => user != null ? emit(AuthState.authenticated(user: user)) : emit(const AuthState.unauthenticated()),
    );
  }
  
  Future<void> _onRefreshTokenRequested(AuthTokenRefreshRequested event, Emitter<AuthState> emit) async {
    
  }
}