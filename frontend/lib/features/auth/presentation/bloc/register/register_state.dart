import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../core/error/failures.dart';

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
  /// The cubit consumer (typically [AuthBloc] listener or router) must
  /// navigate to the home screen or trigger a login sequence.
  const factory RegisterState.success() = RegisterSuccess;

  /// The last registration attempt failed.
  ///
  /// [failure] carries a typed [Failure] variant to be displayed in the UI.
  const factory RegisterState.failure({
    required Failure failure,
  }) = RegisterFailureState;
}