import 'package:either_dart/either.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Abstract base class for all use cases in the application.
///
/// Each use case encapsulates a single application operation and is a
/// callable class via [call].  The [Type] parameter is the success value type;
/// [Params] carries the input parameters.
///
/// All concrete use cases must extend this class and implement [call].
///
/// Example:
/// ```dart
/// class LoginUseCase extends UseCase<UserEntity, LoginParams> {
///   @override
///   Future<Either<Failure, UserEntity>> call(LoginParams params) async { ... }
/// }
/// ```
abstract class UseCase<Type, Params> {
  /// Executes the use case with the given [params].
  ///
  /// Returns [Right<Failure, Type>] on success and [Left<Failure, Type>] on
  /// failure.  No exception escapes this boundary.
  Future<Either<Failure, Type>> call(Params params);
}

/// Sentinel parameter type for use cases that require no input.
///
/// Extends [Equatable] so that instances compare structurally, which is
/// required by bloc_test and mocktail matchers.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}