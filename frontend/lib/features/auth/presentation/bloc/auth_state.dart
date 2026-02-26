import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';

part 'auth_state.freezed.dart';

/// Sealed union of all states emitted by [AuthBloc].
///
/// Declared with [@freezed] for exhaustive pattern matching and structural
/// equality.  The UI layer reacts to these states via [BlocBuilder] and
/// [BlocListener].
///
/// State machine transitions:
/// ```
/// initial
///   └─▶ loading  (on any event)
///         ├─▶ authenticated     (on successful login / check)
///         ├─▶ unauthenticated   (on logout / no session)
///         └─▶ failure           (on error)
/// ```
@freezed
sealed class AuthState with _$AuthState {
  /// Initial state before any authentication operation has been attempted.
  ///
  /// The UI must not render any authenticated content in this state.
  const factory AuthState.initial() = AuthInitial;

  /// An authentication operation is in progress.
  ///
  /// The UI must display a loading indicator and disable interactive controls.
  const factory AuthState.loading() = AuthLoading;

  /// A valid session exists for [user].
  ///
  /// The UI must navigate to the home screen and grant access to protected
  /// features.
  const factory AuthState.authenticated({
    required UserEntity user,
  }) = AuthAuthenticated;

  /// No valid session exists.
  ///
  /// The UI must navigate to the login screen.
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  /// The last authentication operation failed.
  ///
  /// [failure] carries a typed [Failure] variant which the UI should
  /// display as an appropriate error message.
  const factory AuthState.failure({
    required Failure failure,
  }) = AuthFailureState;
}