import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { Request } from 'express';
import { ExtractJwt, Strategy } from 'passport-jwt';

import { JwtRefreshPayload } from '../types/jwt-payload.type';

/**
 * Passport JWT strategy for **refresh tokens**.
 *
 * Extracts the Bearer token from the `Authorization` header of the
 * `POST /auth/refresh` request and verifies it against
 * `JWT_REFRESH_SECRET` — a secret distinct from `JWT_ACCESS_SECRET`.
 *
 * The raw token string is passed through to `validate()` via
 * `passReqToCallback: true`, enabling AuthService to compare it against
 * the stored hash (OWASP A07 — token rotation).
 *
 * Used exclusively by {@link JwtRefreshGuard}.
 */
@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(
  Strategy,
  'jwt-refresh',
) {
  constructor(private readonly configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
      passReqToCallback: true,
    });
  }

  /**
   * Called by Passport after signature and expiry verification.
   *
   * Returns the payload enriched with the raw token string so that
   * `AuthService.refreshTokens` can compare it against the stored hash
   * and invalidate it after rotation.
   */
  validate(
    request: Request,
    payload: JwtRefreshPayload,
  ): JwtRefreshPayload & { refreshToken: string } {
    const authHeader = request.headers.authorization ?? '';
    const refreshToken = authHeader.replace(/^Bearer\s+/i, '');
    return { ...payload, refreshToken };
  }
}