import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

///Sealed union of all typed  failures that can cross the repository boundary.
///
/// All repository and use case return types carry [Either<Failure, T>].
/// The [Left] side always wraps a [Failure] variant; the [Right] side carries
/// the success value.  No raw exceptions are exposed beyond the data layer.
///
/// Usage with either_dart:
///```dart
/// result.fold(
///   (failure) => switch (failure) {
///     ServerFailure(:final statusCode) => ...,
///     NetworkFailure()                 => ...,
///     CacheFailure(:final message)     => ...,
///     AuthFailure(:final message)      => ...,
///     NotFoundFailure()                => ...,
///     ValidationFailure(:final errors) => ...,
///     FirebaseFailure(:final message)  => ...,
///   },
///   (value) => ...,
/// );
/// ```
@freezed
sealed class Failure with _$Failure {
  /// HTTP or NestJS API error.
  const factory Failure.server({
    required int statusCode,
    required String message,
  }) = ServerFailure;

  /// No network connectivity; request could not be initiated.
  const factory Failure.network() = NetworkFailure;

  /// Error reading or writing from local secure storage.
  const factory Failure.cache({required String message}) = CacheFailure;

  /// Authentication or authorisation error (invalid credentials, expired token).
  const factory Failure.auth({required String message}) = AuthFailure;

  /// Requested resource does not exist on the server.
  const factory Failure.notFound() = NotFoundFailure;

  /// Input validation failed before reaching the server.
  const factory Failure.validation({required Map<String, String> errors}) =
      ValidationFailure;
}
