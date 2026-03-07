import {
  ForbiddenException,
  Inject,
  Injectable,
} from '@nestjs/common';
import {JwtService, JwtSignOptions} from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

import {UsersService} from '../users/users.service';
import {UserEntity} from '../users/entities/user.entity';
import {RegisterDto} from './dto/register.dto';
import {AuthResponseDto, MeResponseDto} from './dto/auth-response.dto';
import {JwtPayload} from './types/jwt-payload.type';
import {jwtConfig} from '../config';
import type {ConfigType} from "@nestjs/config";

/** bcrypt cost factor. 12 rounds is the current OWASP recommended minimum. */
const BCRYPT_ROUNDS = 12;

/**
 * Core authentication service.
 *
 * Orchestrates account creation, credential validation, token issuance,
 * token rotation, session invalidation, and current-user retrieval.
 *
 * Configuration is injected via the typed `jwt` namespace
 * (`@Inject(jwtConfig.KEY)`) rather than raw `ConfigService.get()` string
 * lookups. This provides compile-time type checking on all JWT parameters.
 *
 * Security posture (OWASP Top 10 / YouTogether_DataModel.docx §8):
 * - A02 — Passwords and refresh tokens are never stored in plain text.
 *   bcrypt hashes are produced with {@link BCRYPT_ROUNDS} rounds.
 * - A07 — Access tokens are short-lived. Refresh tokens are rotated on
 *   every use; the old hash is invalidated before a new pair is issued.
 *   Logout sets `refresh_token_hash` to NULL server-side.
 * - A09 — No credential values appear in log output. Errors carry only
 *   generic messages to prevent user enumeration.
 */
@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    @Inject(jwtConfig.KEY)
    private readonly jwt: ConfigType<typeof jwtConfig>,
  ) {}

  // ---------------------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------------------

  /**
   * Creates a new user account and issues an initial token pair.
   *
   * Hashing is done here rather than in UsersService so that the
   * persistence layer never receives a plain-text password.
   *
   * Propagates {@link ConflictException} (409) from UsersService when
   * the email is already in use.
   */
  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);

    const user = await this.usersService.create({
      email: dto.email,
      passwordHash,
      username: dto.username,
    });

    return this.issueSessionFor(user);
  }

  // ---------------------------------------------------------------------------
  // Login — credential validation
  // ---------------------------------------------------------------------------

  /**
   * Validates email/password credentials against the stored bcrypt hash.
   *
   * Called by {@link LocalStrategy} before the route handler.
   *
   * Returns the {@link UserEntity} on success, or `null` on failure.
   * The caller (LocalStrategy) is responsible for throwing the 401.
   * Returning `null` rather than throwing here prevents inconsistent
   * error shapes when Passport wraps this call (OWASP A07).
   */
  async validateLocalUser(
    email: string,
    password: string,
  ): Promise<UserEntity | null> {
    const user = await this.usersService.findByEmail(email, true);

    if (!user) {
      // Perform a dummy hash comparison to maintain constant response time
      // regardless of whether the user exists (prevents timing attacks).
      await bcrypt.compare(
        password,
        '$2b$12$dummyhashfortimingnormalisation00000000000000',
      );
      return null;
    }

    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);

    if (!isPasswordValid) {
      return null;
    }

    return user;
  }

  /**
   * Issues a token pair for a user validated by {@link LocalStrategy}.
   *
   * `request.user` is the {@link UserEntity} attached by Passport after
   * {@link LocalStrategy.validate} returns successfully.
   */
  async login(user: UserEntity): Promise<AuthResponseDto> {
    return this.issueSessionFor(user);
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  /**
   * Invalidates the current session by setting `refresh_token_hash` to
   * NULL in the database (OWASP A07).
   *
   * The access token remains technically valid until its TTL expires,
   * but it cannot be used to obtain a new session after logout.
   */
  async logout(userId: string): Promise<void> {
    await this.usersService.updateRefreshTokenHash(userId, null);
  }

  // ---------------------------------------------------------------------------
  // Token refresh
  // ---------------------------------------------------------------------------

  /**
   * Rotates the token pair for an authenticated session.
   *
   * Validation steps (OWASP A07):
   * 1. Retrieve the user and their stored `refresh_token_hash`.
   * 2. Verify the provided raw token against the stored hash.
   * 3. Issue a new access + refresh pair.
   * 4. Persist the new refresh token hash (invalidating the old one).
   *
   * Throws {@link ForbiddenException} (403) when the refresh token does
   * not match — indicates a reuse attempt after rotation (token theft).
   * In that case, the entire session is also invalidated to limit exposure.
   */
  async refreshTokens(
    userId: string,
    rawRefreshToken: string,
  ): Promise<AuthResponseDto> {
    const user = await this.usersService.findById(userId, true);

    if (!user.refreshTokenHash) {
      throw new ForbiddenException('No active session found.');
    }

    const isTokenValid = await bcrypt.compare(
      rawRefreshToken,
      user.refreshTokenHash,
    );

    if (!isTokenValid) {
      // Possible token reuse after rotation — invalidate session entirely.
      await this.usersService.updateRefreshTokenHash(userId, null);
      throw new ForbiddenException(
        'Refresh token is invalid. Please log in again.',
      );
    }

    return this.issueSessionFor(user);
  }

  // ---------------------------------------------------------------------------
  // Get current user
  // ---------------------------------------------------------------------------

  /**
   * Returns the profile of the currently authenticated user.
   *
   * Relies on `userId` extracted from the validated JWT payload — no
   * password or token data is returned (OWASP A09).
   */
  async getMe(userId: string): Promise<MeResponseDto> {
    const user = await this.usersService.findById(userId);
    return MeResponseDto.from(user);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /**
   * Issues a new access + refresh token pair for the given user, persists
   * the refresh token hash, and returns the full {@link AuthResponseDto}.
   *
   * This method is the single point of token issuance. All paths that
   * establish or renew a session call it to guarantee consistent behaviour.
   * Both tokens are signed in parallel via `Promise.all` to minimise latency.
   */
  private async issueSessionFor(user: UserEntity): Promise<AuthResponseDto> {
    const payload: JwtPayload = { sub: user.id, email: user.email };

    const accessOptions: JwtSignOptions = {
      secret: this.jwt.accessSecret,
      expiresIn: this.jwt.accessExpiresIn,
    };
    const refreshOptions: JwtSignOptions = {
      secret: this.jwt.refreshSecret,
      expiresIn: this.jwt.refreshExpiresIn,
    };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, accessOptions),
      this.jwtService.signAsync(payload, refreshOptions),
    ]);

    // Hash the refresh token before persistence (OWASP A02).
    const refreshTokenHash = await bcrypt.hash(refreshToken, BCRYPT_ROUNDS);
    await this.usersService.updateRefreshTokenHash(user.id, refreshTokenHash);

    return AuthResponseDto.from(user, accessToken, refreshToken);
  }
}