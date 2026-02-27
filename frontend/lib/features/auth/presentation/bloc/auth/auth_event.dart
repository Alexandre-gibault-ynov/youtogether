import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_event.freezed.dart';

/// Sealed union of all events that [AuthBloc] can handle.
///
/// Declared with [@freezed] to generate exhaustive pattern matching via
/// [map] / [maybeMap] / [when].  The presentation layer dispatches these
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

  /// Dispatched when the user triggers logout from the navigation menu.
  ///
  /// Triggers [LogoutUseCase] and transitions to [AuthState.unauthenticated].
  const factory AuthEvent.logoutRequested() = AuthLogoutRequested;

  /// Dispatched on application cold start to restore the session state.
  ///
  /// Triggers [GetCurrentUserUseCase]; navigates to the login screen if no
  /// valid session is found.
  const factory AuthEvent.checkStatusRequested() = AuthCheckStatusRequested;

  /// Dispatched internally by the BLoC when the Dio interceptor receives a
  /// 401 Unauthorized response.
  ///
  /// Triggers [RefreshTokenUseCase].  On failure, transitions to
  /// [AuthState.unauthenticated].
  const factory AuthEvent.tokenRefreshRequested() = AuthTokenRefreshRequested;
}
