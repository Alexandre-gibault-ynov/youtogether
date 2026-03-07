# YouTogether — Backend Authentication Module

**Version:** 1.1.0 — February 2026

---

## Overview

NestJS authentication module for the YouTogether backend. Exposes the
five endpoints consumed by the Flutter `IAuthRemoteDataSource`:

| Method | Path               | Guard        | Description                           |
|--------|--------------------|--------------|---------------------------------------|
| POST   | /api/auth/register | `@Public`    | Create account and issue token pair   |
| POST   | /api/auth/login    | `LocalAuth`  | Validate credentials and issue tokens |
| POST   | /api/auth/logout   | `JwtAuth`    | Invalidate refresh token server-side  |
| POST   | /api/auth/refresh  | `JwtRefresh` | Rotate token pair                     |
| GET    | /api/auth/me       | `JwtAuth`    | Return authenticated user profile     |

---

## Directory Structure

```
src/
├── config/                              # Typed configuration namespaces
│   ├── app.config.ts                    # AppConfig { port, nodeEnv, corsOrigin }
│   ├── database.config.ts               # DatabaseConfig { host, port, ... }
│   ├── jwt.config.ts                    # JwtConfig { accessSecret, refreshSecret, ... }
│   └── index.ts                         # Barrel re-export for all namespaces
│
├── common/
│   └── filters/
│       └── http-exception.filter.ts     # Global error normaliser → ErrorResponseBody
│
├── auth/
│   ├── decorators/
│   │   ├── current-user.decorator.ts    # Extracts JwtPayload from request
│   │   └── public.decorator.ts          # @Public() — bypass JwtAuthGuard
│   ├── dto/
│   │   ├── register.dto.ts              # Validated body for POST /auth/register
│   │   ├── login.dto.ts                 # Validated body for POST /auth/login
│   │   └── auth-response.dto.ts         # AuthResponseDto + MeResponseDto
│   ├── guards/
│   │   └── auth.guards.ts               # LocalAuthGuard, JwtAuthGuard (global), JwtRefreshGuard
│   ├── strategies/
│   │   ├── local.strategy.ts            # Passport Local — validates email/password
│   │   ├── jwt.strategy.ts              # Passport JWT — validates access tokens
│   │   └── jwt-refresh.strategy.ts      # Passport JWT-Refresh — validates refresh tokens
│   ├── types/
│   │   └── jwt-payload.type.ts          # JwtPayload and JwtRefreshPayload interfaces
│   ├── auth.controller.ts               # REST handlers for all auth endpoints
│   ├── auth.module.ts                   # Feature module — wires global JwtAuthGuard
│   └── auth.service.ts                  # Business logic: register, login, logout, refresh, me
│
├── users/
│   ├── entities/
│   │   └── user.entity.ts               # TypeORM entity matching data model §2.1.1
│   ├── users.module.ts
│   └── users.service.ts                 # CRUD operations on the users table
│
├── app.module.ts                        # Root module: typed ConfigModule + TypeORM
└── main.ts                              # Bootstrap: filter, ValidationPipe, typed config

test/
├── auth/
│   ├── auth.service.spec.ts             # 14 unit tests — AuthService
│   ├── auth.controller.spec.ts          #  9 unit tests — AuthController
│   └── users.service.spec.ts            #  9 unit tests — UsersService
├── common/
│   └── http-exception.filter.spec.ts    # 11 unit tests — HttpExceptionFilter
└── config/
    └── jwt.config.spec.ts               #  4 unit tests — jwtConfig factory
```

---

## Architecture Decisions

### Typed configuration namespaces

Environment variables are not accessed directly via `process.env` or raw
`ConfigService.get('KEY')` string lookups outside the configuration
files themselves. Each concern is encapsulated in a `registerAs` namespace:

| Namespace  | Token constant       | Interface        | Consumers                                          |
|------------|----------------------|------------------|----------------------------------------------------|
| `app`      | `appConfig.KEY`      | `AppConfig`      | `main.ts`                                          |
| `database` | `databaseConfig.KEY` | `DatabaseConfig` | `AppModule` (TypeORM wiring)                       |
| `jwt`      | `jwtConfig.KEY`      | `JwtConfig`      | `AuthService`, `JwtStrategy`, `JwtRefreshStrategy` |

Consumers inject typed values via `@Inject(jwtConfig.KEY)` with
`ConfigType<typeof jwtConfig>`. The compiler enforces the interface — a
renamed or missing field causes a build error rather than a silent
runtime `undefined`.

`AppModule` declares `ConfigModule.forRoot({ load: [appConfig, databaseConfig, jwtConfig] })`.
`AuthModule` additionally calls `ConfigModule.forFeature(jwtConfig)` to
register the namespace token in the feature module's local DI container,
which is required for `@Inject(jwtConfig.KEY)` to resolve.

### Fail-fast configuration validation

The `jwtConfig` and `databaseConfig` factory functions throw an explicit
`Error` at module initialization if a required environment variable is
absent. This prevents the application from starting with an insecure or
broken configuration (OWASP A05). The error is thrown before any port is
bound, making misconfiguration immediately visible in deployment pipelines.

### Normalised error responses

`HttpExceptionFilter` is registered globally via `app.useGlobalFilters()`.
Every error response — regardless of its origin (Passport, ValidationPipe,
service layer, unhandled exception) — shares the `ErrorResponseBody`
envelope:

```json
{
  "statusCode": 409,
  "error": "Conflict",
  "message": "An account with this email address already exists.",
  "errors": null,
  "timestamp": "2026-02-27T14:32:00.000Z",
  "path": "/api/auth/register"
}
```

For HTTP 422 (validation failure), the `errors` field carries a
field-keyed map that maps directly to `ValidationFailure.errors` on the
Flutter client:

```json
{
  "statusCode": 422,
  "error": "Unprocessable Entity",
  "message": "Validation failed.",
  "errors": {
    "email": "email must be a valid email address.",
    "password": "password must be at least 8 characters."
  }
}
```

This is produced by the `exceptionFactory` in `ValidationPipe`, which
converts class-validator constraint arrays into a `Record<string, string>`
before wrapping them in `UnprocessableEntityException`. The filter then
deserializes this structured body and places it in `errors`.

Non-`HttpException` values (unhandled errors) produce HTTP 500 with a
generic message, preventing internal details from reaching the client
(OWASP A09).

### Security-by-default routing

`JwtAuthGuard` is registered as a global `APP_GUARD`. Every route is
protected by default. Endpoints that must be publicly accessible
(`/register`, `/login`, `/refresh`) are decorated with `@Public()`,
which sets a metadata flag that the guard reads via `Reflector`.

### Token strategy

Access tokens and refresh tokens are signed with **distinct secrets**
(`jwt.accessSecret` vs `jwt.refreshSecret`) and **distinct TTLs**
(default 15 min vs 7 days). This prevents a leaked access token from
being used to obtain a new session.

Refresh tokens are stored as **bcrypt hashes** in `users.refresh_token_hash`.
The raw token is never persisted. On each refresh, the stored hash is
compared against the incoming token, the old hash is invalidated, and a
new pair is issued (**token rotation**). A hash mismatch invalidates the
entire session to limit exposure after a possible token theft.

### Timing-safe credential validation

When `validateLocalUser` receives an unknown email, it performs a dummy
`bcrypt.compare` to maintain a constant response time regardless of
whether the user exists, preventing timing-based user enumeration
(OWASP A07).

---

## Security Alignment (OWASP Top 10)

| OWASP                           | Measure                                                                                                                                                                                                                |
|---------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| A02 — Cryptographic Failures    | Passwords hashed with bcrypt (12 rounds). Refresh tokens hashed before persistence. `password_hash` and `refresh_token_hash` columns declared with `select: false`.                                                    |
| A03 — Injection                 | TypeORM QueryBuilder with parameterised bindings. `ValidationPipe(whitelist: true)` strips undeclared request body fields.                                                                                             |
| A05 — Security Misconfiguration | `jwtConfig` and `databaseConfig` throw at startup when required variables are absent. `synchronize: false` in production prevents accidental schema destruction.                                                       |
| A07 — Auth Failures             | Short-lived access tokens (15 min). Refresh token rotation on every use. Logout nullifies `refresh_token_hash`. Token mismatch on refresh invalidates the entire session. Timing-safe login prevents user enumeration. |
| A09 — Logging Failures          | No credential values in log output. `HttpExceptionFilter` produces generic 500 messages for unhandled errors. Field-keyed validation errors contain no sensitive data.                                                 |

---

## Getting Started

```bash
# 1. Copy environment template and fill in values
cp .env.example .env

# 2. Install dependencies
npm install

# 3. Start the API in development mode
npm run start:dev

# 4. Run all tests
npm test

# 5. Run tests with coverage report
npm run test:cov
```

### Required environment variables

| Variable                 | Description                                       | Default       |
|--------------------------|---------------------------------------------------|---------------|
| `DB_HOST`                | PostgreSQL host                                   | —             |
| `DB_PORT`                | PostgreSQL port                                   | `5432`        |
| `DB_USERNAME`            | PostgreSQL username                               | —             |
| `DB_PASSWORD`            | PostgreSQL password                               | —             |
| `DB_NAME`                | PostgreSQL database name                          | —             |
| `JWT_ACCESS_SECRET`      | Secret for signing access tokens (min. 32 chars)  | required      |
| `JWT_ACCESS_EXPIRES_IN`  | Access token TTL                                  | `15m`         |
| `JWT_REFRESH_SECRET`     | Secret for signing refresh tokens (min. 32 chars) | required      |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token TTL                                 | `7d`          |
| `PORT`                   | HTTP listening port                               | `3000`        |
| `NODE_ENV`               | `development` \| `production` \| `test`           | `development` |
| `CORS_ORIGIN`            | Allowed CORS origin                               | `*`           |

Variables marked **required** cause the application to refuse to start
if absent. All others have safe defaults.

---

## Running Tests

```bash
# All tests
npm test

# Single test file
npx jest test/auth/auth.service.spec.ts
npx jest test/common/http-exception.filter.spec.ts
npx jest test/config/jwt.config.spec.ts

# Coverage report (output in ./coverage/html/)
npm run test:cov
```

### Test coverage targets

| Test file                                   | Subject                                                                             | Cases  |
|---------------------------------------------|-------------------------------------------------------------------------------------|--------|
| `test/auth/auth.service.spec.ts`            | `AuthService` — register, login, logout, refresh, getMe (success + failure paths)   | 14     |
| `test/auth/auth.controller.spec.ts`         | `AuthController` — all five endpoints, delegation, HTTP semantics                   | 9      |
| `test/auth/users.service.spec.ts`           | `UsersService` — create, findByEmail, findById, updateRefreshTokenHash              | 9      |
| `test/common/http-exception.filter.spec.ts` | `HttpExceptionFilter` — all status codes, 422 formats, 500 fallback, envelope shape | 11     |
| `test/config/jwt.config.spec.ts`            | `jwtConfig` — correct values, default TTLs, fail-fast on missing secrets            | 4      |
| **Total**                                   |                                                                                     | **47** |

---

## Dependencies

| Package                                | Role                                               |
|----------------------------------------|----------------------------------------------------|
| `@nestjs/jwt`                          | JWT signing and verification                       |
| `@nestjs/passport`                     | Passport.js integration                            |
| `@nestjs/config`                       | Typed configuration namespaces via `registerAs`    |
| `passport-local`                       | Email/password credential strategy                 |
| `passport-jwt`                         | JWT Bearer token strategy (access + refresh)       |
| `bcrypt`                               | Password and refresh token hashing (12 rounds)     |
| `class-validator`                      | DTO input validation constraints                   |
| `class-transformer`                    | DTO transformation (lowercase email normalisation) |
| `typeorm` + `pg`                       | PostgreSQL ORM with parameterised queries          |
| `@nestjs/testing` + `jest` + `ts-jest` | Unit testing framework                             |