// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/user_entity.dart';

part 'auth_event.freezed.dart';

/// Sealed union of all events that [AuthBloc] can handle.
///
/// Declared with [@freezed] to generate exhaustive pattern matching via
/// [map] / [maybeMap] / [when]. The presentation layer dispatches these
/// events; the BLoC processes them and emits [AuthState] transitions.
@freezed
sealed class AuthEvent with _$AuthEvent {
  /// Dispatched when the user submits the login form.
  ///
  /// Triggers [LoginUseCase] with the supplied credentials.
  const factory AuthEvent.loginRequested({
    required String email,
    required String password,
  }) = AuthLoginRequested;

  /// Dispatched when the user triggers logout from the profile screen.
  ///
  /// Triggers [LogoutUseCase] and transitions to [AuthState.unauthenticated].
  const factory AuthEvent.logoutRequested() = AuthLogoutRequested;

  /// Dispatched on application cold start to restore the session state.
  ///
  /// Triggers [GetCurrentUserUseCase]; transitions to [AuthState.unauthenticated]
  /// if no valid session is found.
  const factory AuthEvent.checkStatusRequested() = AuthCheckStatusRequested;

  /// Dispatched internally by the BLoC when the Dio interceptor receives a
  /// 401 Unauthorized response.
  ///
  /// Triggers [RefreshTokenUseCase]. On failure, transitions to
  /// [AuthState.unauthenticated].
  const factory AuthEvent.tokenRefreshRequested() = AuthTokenRefreshRequested;

  /// Dispatched by [RegisterPage] after [RegisterCubit] emits
  /// [RegisterState.success].
  ///
  /// The registration endpoint returns a full session (access_token +
  /// refresh_token + user). Tokens are already persisted in secure storage by
  /// [AuthRepositoryImpl.register]. This event allows [AuthBloc] to
  /// immediately transition to [AuthState.authenticated] without an additional
  /// network round trip to [GetCurrentUserUseCase].
  ///
  /// This event is exclusive to the post-registration auto-login flow.
  const factory AuthEvent.userSessionEstablished({
    required UserEntity user,
  }) = AuthUserSessionEstablished;
}