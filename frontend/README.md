# YouTogether — Authentication Feature

**Document Version:** 1.1.0 — February 2026

---

## Overview

This document describes the implementation of the authentication feature for
the YouTogether Flutter application. The feature covers:

- User login via email and password
- User account registration
- Session restoration on application cold start
- Token refresh (silent, interceptor-driven)
- Logout

The implementation follows **Clean Architecture** with **BLoC**,
**Domain-Driven Design (DDD)**, and **Test-Driven Development (TDD)**.

---

## Directory Structure

```
lib/
├── app/
│   └── app_theme.dart               # Centralised design tokens and ThemeData
│
├── core/
│   ├── error/
│   │   ├── exceptions.dart          # Raw data-layer exceptions
│   │   └── failures.dart            # Sealed Failure union (domain layer)
│   └── usecases/
│       └── use_case.dart            # Abstract UseCase<T, P> base class + NoParams
│
└── features/
    ├── auth/
    │   ├── domain/                  # Innermost ring — no framework dependencies
    │   │   ├── entities/
    │   │   │   └── user_entity.dart          # @freezed UserEntity + UserRole enum
    │   │   ├── repositories/
    │   │   │   └── i_auth_repository.dart    # Abstract repository interface
    │   │   └── usecases/
    │   │       ├── login_use_case.dart               # LoginParams + LoginUseCase
    │   │       ├── login_with_google_use_case.dart   # LoginWithGoogleUseCase
    │   │       ├── logout_use_case.dart               # LogoutUseCase
    │   │       ├── get_current_user_use_case.dart     # GetCurrentUserUseCase
    │   │       ├── refresh_token_use_case.dart        # RefreshTokenUseCase
    │   │       └── register_use_case.dart             # RegisterParams + RegisterUseCase
    │   │
    │   ├── data/                    # Implementations — framework and I/O aware
    │   │   ├── datasources/
    │   │   │   ├── i_auth_remote_data_source.dart    # Remote (Dio/NestJS) interface
    │   │   │   └── i_auth_local_datasource.dart      # Local (flutter_secure_storage) interface
    │   │   ├── models/
    │   │   │   ├── user_model.dart   # @freezed + @JsonSerializable + toDomain()
    │   │   │   └── token_model.dart  # @freezed + @JsonSerializable
    │   │   └── repositories/
    │   │       └── auth_repository_impl.dart         # IAuthRepository implementation
    │   │
    │   └── presentation/            # BLoC + UI
    │       ├── bloc/
    │       │   ├── auth_event.dart         # @freezed sealed AuthEvent union
    │       │   ├── auth_state.dart         # @freezed sealed AuthState union
    │       │   ├── auth_bloc.dart          # AuthBloc — session state machine
    │       │   └── register/
    │       │       ├── register_state.dart # @freezed sealed RegisterState union
    │       │       └── register_cubit.dart # RegisterCubit — registration flow
    │       └── pages/
    │           ├── login_page.dart         # Login screen (email/password)
    │           └── register_page.dart      # Account creation screen
    │
    └── room/
        └── presentation/
            └── pages/
                └── home_page.dart          # Public room listing + auth-aware AppBar

test/
└── features/
    └── auth/
        ├── domain/
        │   └── usecases/
        │       ├── login_use_case_test.dart
        │       ├── get_current_user_use_case_test.dart
        │       └── register_use_case_test.dart
        ├── data/
        │   └── repositories/
        │       └── auth_repository_impl_test.dart
        └── presentation/
            └── bloc/
                ├── auth_bloc_test.dart
                └── register/
                    └── register_cubit_test.dart
```

---

## Architecture Layers

### Domain Layer

The domain layer is framework-agnostic. It contains:

- **UserEntity** — immutable entity declared with `@freezed`. No `fromJson`/`toJson`.
- **IAuthRepository** — abstract interface defining the full authentication contract
  including the `register()` method added in v1.1.0. Concrete implementations are in
  the data layer and injected via `get_it`.
- **Use Cases** — each use case encapsulates one operation and extends
  `UseCase<T, Params>`. All return `Either<Failure, T>`.

| Use Case | Params | Return |
|---|---|---|
| `LoginUseCase` | `LoginParams { email, password }` | `Either<Failure, UserEntity>` |
| `LoginWithGoogleUseCase` | `NoParams` | `Either<Failure, UserEntity>` |
| `LogoutUseCase` | `NoParams` | `Either<Failure, void>` |
| `GetCurrentUserUseCase` | `NoParams` | `Either<Failure, UserEntity?>` |
| `RefreshTokenUseCase` | `NoParams` | `Either<Failure, void>` |
| `RegisterUseCase` | `RegisterParams { email, password, username }` | `Either<Failure, UserEntity>` |

### Data Layer

The data layer implements the repository and data source interfaces:

- **AuthRepositoryImpl** — orchestrates calls between `IAuthRemoteDataSource`
  (NestJS REST via Dio) and `IAuthLocalDataSource` (flutter_secure_storage).
  Maps raw exceptions to typed `Failure` objects before returning `Either`.
  The `register()` method applies semantic HTTP code mapping: 409 → `ValidationFailure`
  with key `email`; 422 → `ValidationFailure` with key `form`.
- **UserModel / TokenModel** — `@freezed` + `@JsonSerializable`. Each model exposes
  a `toDomain()` extension method as the sole crossing point from the data layer to
  the domain.
- **IAuthRemoteDataSource** — extended in v1.1.0 with `register()` targeting
  `POST /auth/register`.
- **IAuthLocalDataSource** — unchanged; handles all token persistence.

### Presentation Layer

- **AuthBloc** — manages session state. Events: login, Google login, logout, check
  status, token refresh. Never catches exceptions; consumes `Either` via `fold()`.
- **RegisterCubit** — manages the account creation flow independently from
  `AuthBloc`, respecting the Single Responsibility Principle. Delegates to
  `RegisterUseCase` via constructor injection.
- **AppTheme** — centralised design system. Dark cinematic theme: charcoal surfaces,
  YouTube-red accent, Georgia serif display titles. All pages reference `AppTheme`;
  no hard-coded colours appear in widget files.
- **LoginPage** — email/password form, "Annuler", "Créer un compte" link.
- **RegisterPage** — email, username, password, confirm-password form.
- **HomePage** — public room listing. AppBar action adapts to `AuthBloc` state:
  "Connexion" when unauthenticated, "Profil" when authenticated.

---

## Error Handling Strategy

```
Data source throws Exception
         │
         ▼
 ┌───────────────────┐
 │ Repository .catch │  exception → typed Failure
 └───────────────────┘
         │
         ▼
 Either<Failure, T>   (Left = Failure, Right = success value)
         │
         ▼
  Use Case passes through unchanged
         │
      ┌──┴──────────────────┐
      ▼                     ▼
  AuthBloc              RegisterCubit
  result.fold()         result.fold()
      │                     │
  ┌───┴───┐             ┌───┴───┐
  ▼       ▼             ▼       ▼
Left    Right         Left    Right
  │       │             │       │
  ▼       ▼             ▼       ▼
Auth    Auth          Reg     Reg
State   State         State   State
.fail   .auth /       .fail   .success
        .unauth
```

No raw exception crosses the repository boundary.

---

## Security Alignment (OWASP Top 10)

| OWASP Category | Measure |
|---|---|
| A02 — Cryptographic Failures | Tokens stored via `flutter_secure_storage` (AES-256 / Keychain). Passwords never stored client-side. |
| A03 — Injection | All API calls use typed DTOs; no raw string interpolation in URL paths. |
| A05 — Security Misconfiguration | Certificate pinning enforced on the Dio instance. |
| A07 — Auth Failures | Access token auto-refresh on 401 via Dio interceptor (`AuthEvent.tokenRefreshRequested`). Token rotation on every refresh. Registration establishes a session immediately, eliminating a redundant login round-trip. |
| A09 — Logging Failures | `Failure` types carry only typed metadata; no raw credentials appear in error objects. |

---

## Code Generation

Generated files (`*.freezed.dart`, `*.g.dart`) are excluded from version control via `.gitignore`.

```bash
# Run once after cloning or when modifying @freezed / @injectable classes:
dart run build_runner build --delete-conflicting-outputs
```

---

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Run a specific test file
flutter test test/features/auth/presentation/bloc/auth_bloc_test.dart
flutter test test/features/auth/presentation/bloc/register/register_cubit_test.dart
```

---

## Acceptance Test Scenarios

| ID | Scenario | Expected State |
|---|---|---|
| TC-01 | User logs in with valid credentials | `AuthState.authenticated` with `UserEntity` |
| TC-02 | User logs in with invalid credentials | `AuthState.failure` with `AuthFailure` |
| TC-03 | Unauthenticated user opens app | `AuthState.unauthenticated` → redirect to login |
| TC-04 | User creates an account with valid inputs | `RegisterState.success` → pop to login |
| TC-05 | User attempts registration with an already-used email | `RegisterState.failure` with `ValidationFailure { email: ... }` |

TC-01 to TC-03 are covered by `auth_bloc_test.dart`.
TC-04 and TC-05 are covered by `register_cubit_test.dart` and `register_use_case_test.dart`.

---

## Dependencies

| Package | Role |
|---|---|
| `flutter_bloc ^8.x` | BLoC and Cubit state management |
| `either_dart ^1.x` | `Either<L, R>` monad for explicit error handling |
| `freezed_annotation ^2.x` | Immutable sealed unions (Entities, Failures, Models, Events, States) |
| `json_serializable ^6.x` | JSON serialisation for data layer models |
| `equatable ^2.x` | Structural equality for `Params` classes |
| `dio ^5.x` | HTTP client for NestJS REST API |
| `flutter_secure_storage ^9.x` | Encrypted token persistence (OWASP A02) |
| `get_it ^7.x` + `injectable ^2.x` | Dependency injection |
| `mocktail ^1.x` | Mock generation for TDD test doubles |
| `bloc_test ^9.x` | BLoC and Cubit-specific test utilities |