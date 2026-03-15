# YouTogether — Flutter Client

Watch-party platform — watch YouTube videos together in real time.

**Version:** 1.1.0 — March 2026

---

## Table of contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project structure](#project-structure)
4. [Architecture](#architecture)
5. [Features](#features)
6. [Getting started](#getting-started)
7. [Environment variables](#environment-variables)
8. [Code generation](#code-generation)
9. [Running the app](#running-the-app)
10. [Testing](#testing)
11. [Design system](#design-system)
12. [Roadmap](#roadmap)

---

## Overview

YouTogether is a Flutter application that communicates with a NestJS REST backend. The current version covers the complete authentication module: registration, login, session restore on cold start, profile display, and logout.

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| Flutter SDK | 3.19 |
| Dart SDK | 3.3 |
| Android SDK (emulator) | API 21+ |
| Xcode (iOS Simulator) | 15+ |
| Node.js | 20 (backend only) |

Verify your environment:

```bash
flutter doctor -v
```

---

## Project structure

```
lib/
├── app/
│   ├── app.dart             # Root widget — BlocProvider, GoRouter, BlocListener
│   └── app_theme.dart       # Design tokens and ThemeData
├── core/
│   ├── error/
│   │   ├── exceptions.dart  # Typed exceptions (AuthException, ServerException…)
│   │   └── failures.dart    # Typed failures (Either left values)
│   ├── network/
│   │   └── auth_interceptor.dart  # Dio interceptor — Bearer token injection
│   ├── router/
│   │   ├── app_router.dart  # GoRouter factory + GoRouterRefreshStream
│   │   └── app_routes.dart  # Route path constants
│   └── usecases/
│       └── use_case.dart    # UseCase<Type, Params> base class
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_local_datasource_impl.dart   # FlutterSecureStorage
│   │   │   │   ├── auth_remote_data_source_impl.dart # Dio — REST calls
│   │   │   │   ├── i_auth_local_datasource.dart
│   │   │   │   └── i_auth_remote_data_source.dart
│   │   │   ├── models/
│   │   │   │   ├── token_model.dart   # JSON ↔ TokenPair
│   │   │   │   └── user_model.dart    # JSON ↔ UserEntity (+ toDomain)
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── i_auth_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_current_user_use_case.dart
│   │   │       ├── login_use_case.dart
│   │   │       ├── login_with_google_use_case.dart  # stub — not yet implemented
│   │   │       ├── logout_use_case.dart
│   │   │       ├── refresh_token_use_case.dart
│   │   │       └── register_use_case.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── auth/
│   │       │   │   ├── auth_bloc.dart
│   │       │   │   ├── auth_event.dart   # @freezed sealed union
│   │       │   │   ├── auth_state.dart   # @freezed sealed union
│   │       │   │
│   │       │   └── register/
│   │       │       ├── register_cubit.dart
│   │       │       └── register_state.dart
│   │       └── pages/
│   │           ├── login_page.dart
│   │           ├── profile_page.dart
│   │           └── register_page.dart
│   └── room/
│       ├── domain/
│       │   └── entities/
│       │       └── room_entity.dart  # MVP stub — driven by RoomBloc later
│       └── presentation/
│           └── pages/
│               └── home_page.dart
├── injection_container.dart  # GetIt service locator
└── main.dart

test/
├── common/
│   └── fixtures/
│       └── fixture_reader.dart          # FixtureDirectory enum
├── core/
│   ├── auth_interceptor_test.dart
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── datasources/
    │   │   │   └── auth_remote_data_source_contract_test.dart
    │   │   └── models/
    │   │       └── user_model_contract_test.dart
    │   ├── fixtures/                    # Captured from real backend responses
    │   │   ├── auth_me_success.json
    │   │   ├── auth_session_success.json
    │   │   ├── error_conflict_409.json
    │   │   ├── error_forbidden_403.json
    │   │   ├── error_unauthorized_401.json
    │   │   └── error_validation_422.json
    │   └── presentation/
    │       └── pages/
    │           └── profile_page_test.dart
    └── room/
        └── presentation/
            └── pages/
                └── home_page_test.dart

integration_test/
└── auth_e2e_test.dart   # 10 E2E scenarios against a live NestJS backend
```

---

## Architecture

The project follows **Clean Architecture** with **BLoC** for state management and **Domain-Driven Design** as the modelling methodology. Every feature is developed **test-first** (TDD).

### Dependency flow

```
Presentation  →  Domain  ←  Data
   (BLoC)     (UseCases)  (Repositories, DataSources, Models)
```

Each layer communicates only with its immediate neighbour. The domain layer has zero Flutter or third-party imports — it is pure Dart.

### Layers

**Presentation** — BLoC / Cubit emit sealed `@freezed` states. Pages hold no business logic; they dispatch events and react to state changes via `BlocBuilder` and `BlocListener`.

**Domain** — Pure Dart. `UseCase<Type, Params>` returns `Either<Failure, Type>`. Entities carry only domain-relevant fields; no serialisation code.

**Data** — Models extend entities and add `fromJson` / `toJson` and a `toDomain()` mapper. `AuthRepositoryImpl` coordinates remote and local data sources. `AuthRemoteDataSourceImpl` maps every Dio error to a typed exception; `AuthLocalDataSourceImpl` stores tokens via `flutter_secure_storage` (AES-256 / Android Keystore / iOS Keychain).

### Network security

`AuthInterceptor` (Dio) reads the access token from `IAuthLocalDataSource` on every outgoing request and injects `Authorization: Bearer <token>`. If no token is found (`CacheException`), the request proceeds without the header — the backend guard handles unauthenticated access.

### Routing

`GoRouter` is wired to `AuthBloc` via `GoRouterRefreshStream`. Route protection is declarative: the `redirect` callback re-evaluates on every `AuthState` emission. Currently only `/profile` is a protected path; the list will grow with the Room and Video modules.

---

## Features

### Implemented (v1.1.0)

**HomePage** (`/`)
- Public room listing (stub — driven by `RoomBloc` in a later iteration).
- AppBar action adapts to auth state: "Connexion" (unauthenticated) → LoginPage, "Profil" (authenticated) → ProfilePage.
- Bottom action bar adapts to auth state:
  - Unauthenticated: "Rejoindre un groupe privé".
  - Authenticated: "Créer un groupe privé" (above) + "Rejoindre un groupe privé".

**Authentication**
- Registration (`POST /auth/register`) with client-side validation and server-side error display.
- Login (`POST /auth/login`) with wrong-credential error via SnackBar.
- Session restore on cold start (`GET /auth/me`).
- Logout (`POST /auth/logout`) — access token injected automatically via `AuthInterceptor`.
- JWT rotation — refresh token consumed on `POST /auth/refresh`.

**ProfilePage** (`/profile`)
- Displays display name, email, role badge, member-since date, and avatar (initials fallback).
- "Se déconnecter" button dispatches `AuthEvent.logoutRequested()` and redirects to `/` on `AuthUnauthenticated`.
- Back navigation preserves the active session.

### Planned

- Room module: create and join public / private rooms (`RoomBloc`, CRUD via REST).
- Video synchronisation: Firebase Realtime Database (`VideoSessionBloc`).
- Profile editing.

---

## Getting started

**Clone and install dependencies:**

```bash
git clone <repo-url>
cd youtogether
flutter pub get
```

**Generate freezed / json_serializable code:**

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Environment variables

All build-time variables are passed via `--dart-define`.

| Variable | Default | Description |
|---|---|---|
| `API_BASE_URL` | `http://10.0.2.2:3000/api` | NestJS backend base URL |

The default targets the Android emulator loopback. Use `http://127.0.0.1:3000/api` for the iOS Simulator, or the LAN IP of the host machine for a physical device.

---

## Code generation

The project uses `build_runner` for `freezed` (sealed unions) and `json_serializable` (model serialisation).

Run once after cloning, and again after any change to a `@freezed` or `@JsonSerializable` class:

```bash
# Full rebuild — safe to use at any time
dart run build_runner build --delete-conflicting-outputs

# Watch mode — reruns on file save during active development
dart run build_runner watch --delete-conflicting-outputs
```

Generated files (`*.freezed.dart`, `*.g.dart`) are committed to version control so that CI does not require a build step.

---

## Running the app

**Android emulator (default):**

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

**iOS Simulator:**

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

**Physical device (replace with host LAN IP):**

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000/api
```

The NestJS backend must be running before launching the app. See the backend `README.md` for startup instructions.

---

## Testing

### Unit and contract tests

These tests run without a backend. Fixtures are captured JSON responses located in `test/features/auth/fixtures/`.

```bash
flutter test
```

**Test inventory:**

| File | Scope | Cases |
|---|---|---|
| `test/core/network/auth_interceptor_test.dart` | AuthInterceptor — token injection | 3 |
| `test/features/auth/data/models/user_model_contract_test.dart` | UserModel JSON contract | 21 |
| `test/features/auth/data/datasources/auth_remote_data_source_contract_test.dart` | AuthRemoteDataSourceImpl | 13 |
| `test/features/auth/presentation/pages/profile_page_test.dart` | ProfilePage widget | 8 |
| `test/features/room/presentation/pages/home_page_test.dart` | HomePage widget — bottom bar | 7 |

### Integration tests (E2E)

These tests require a running NestJS backend. Each run creates a unique timestamped account to avoid conflicts on a shared database.

```bash
# Start the backend first
cd youtogether_backend && npm run start:dev

# Run E2E suite
flutter test integration_test/auth_e2e_test.dart \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

**E2E scenario catalogue:**

| ID | Scenario | Prerequisite |
|---|---|---|
| TC-E2E-01 | Cold-start displays unauthenticated HomePage | — |
| TC-E2E-02 | Navigate to LoginPage | — |
| TC-E2E-03 | Navigate from LoginPage to RegisterPage | — |
| TC-E2E-04 | Client-side validation on empty registration form | — |
| TC-E2E-05 | Full registration flow (real backend) | — |
| TC-E2E-06 | Login with wrong password shows error SnackBar | TC-E2E-05 |
| TC-E2E-08 | Cancel registration returns to LoginPage | — |
| TC-E2E-07 | Full login flow (real backend) | TC-E2E-05 |
| TC-E2E-09 | Navigate to ProfilePage and verify user information | TC-E2E-07 |
| TC-E2E-10 | Logout from ProfilePage returns to unauthenticated HomePage | TC-E2E-07 |

> TC-E2E-08 runs before TC-E2E-07 in the suite. Once authenticated, reaching LoginPage requires a logout; the cancel-registration scenario is therefore validated before the session is established.

### Fixtures

Fixtures are located in `test/features/auth/fixtures/` and are read via `FixtureDirectory.auth.read('filename.json')`. Adding a new feature module requires only a new enum value in `test/common/fixtures/fixture_reader.dart`.

---

## Design system

All design tokens are defined in `lib/app/app_theme.dart`. No colour or typography value appears outside this file.

**Palette — dark cinematic:**

| Token | Value | Usage |
|---|---|---|
| `backgroundDark` | `#0D0D12` | Scaffold background |
| `surfaceDark` | `#16161E` | AppBar, elevated surfaces |
| `cardDark` | `#1E1E28` | Cards, input fields, bottom bar |
| `accent` | `#E53935` | Primary actions, focus rings |
| `textPrimary` | `#F0EFF4` | Body text, titles |
| `textSecondary` | `#8A8A9E` | Labels, captions, secondary actions |

**Typography scale:** `displayTitle` (Georgia 26pt) / `sectionHeading` (13pt w600 tracked) / `body` (15pt) / `caption` (13pt muted).

---

## Roadmap

| Version | Milestone |
|---|---|
| v1.0.0 | Auth backend (NestJS) — JWT rotation, 47 unit tests |
| v1.1.0 | Flutter auth module — Clean Architecture, BLoC, 52 tests, 10 E2E scenarios |
| v1.2.0 | Room module — create / join public and private rooms |
| v1.3.0 | Video synchronisation — Firebase Realtime Database |