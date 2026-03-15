// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../core/error/failures.dart';
import '../../../domain/entities/user_entity.dart';

part 'register_state.freezed.dart';

/// Sealed union of all states emitted by [RegisterCubit].
///
/// Follows the same [@freezed] convention as [AuthState] for consistency
/// across the presentation layer.
@freezed
sealed class RegisterState with _$RegisterState {
  /// Initial state before any registration attempt.
  const factory RegisterState.initial() = RegisterInitial;

  /// Registration request is in progress.
  ///
  /// The UI must display a loading indicator and disable all controls.
  const factory RegisterState.loading() = RegisterLoading;

  /// Registration completed successfully.
  ///
  /// [user] carries the newly created [UserEntity] returned by the backend.
  /// Tokens are already persisted in secure storage.
  ///
  /// [RegisterPage] must dispatch [AuthEvent.userSessionEstablished] with
  /// this [user] to [AuthBloc] so that the application immediately transitions
  /// to [AuthState.authenticated] without an extra network round trip.
  const factory RegisterState.success({
    required UserEntity user,
  }) = RegisterSuccess;

  /// The last registration attempt failed.
  ///
  /// [failure] carries a typed [Failure] variant to be displayed in the UI.
  const factory RegisterState.failure({
    required Failure failure,
  }) = RegisterFailureState;
}