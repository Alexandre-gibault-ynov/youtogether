import 'package:either_dart/either.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/register/register_state.dart';

import '../../../../../core/error/failures.dart';
import '../../../domain/usecases/register_use_case.dart';

/// Cubit managing the account creation flow.
///
/// Exposes a single [register] method that validates inputs and delegates to
/// [IRegisterUseCase] once the domain contract is in place.
///
/// Separated from [AuthBloc] to respect the Single Responsibility Principle:
/// registration is a distinct operation from session management.
class RegisterCubit extends Cubit<RegisterState> {
  final RegisterUseCase _registerUseCase;

  RegisterCubit({required RegisterUseCase registerUseCase})
    : _registerUseCase = registerUseCase,
      super(const RegisterState.initial());

  /// Submits a registration request with [email], [password] and [username].
  ///
  /// Emits [RegisterState.loading] while the request is in flight, then:
  /// - [RegisterState.success] — account created, session tokens persisted.
  /// - [RegisterState.failure] — typed [Failure] ready for UI display.
  ///
  /// Client-side validation is handled upstream by the [Form] widget in
  /// [RegisterPage]; this method assumes valid input.
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    emit(const RegisterState.loading());

    final result = _registerUseCase(
      RegisterParams(username: username, email: email, password: password),
    );

    result.fold(
      (failure) => emit(RegisterState.failure(failure: failure)),
      (user) => emit(RegisterState.success(user: user)),
    );
  }

  /// Resets the cubit to [RegisterState.initial].
  ///
  /// Called when the user navigates away before completing registration.
  void reset() => emit(const RegisterState.initial());
}
