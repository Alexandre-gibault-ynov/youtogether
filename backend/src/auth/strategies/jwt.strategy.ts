import { Inject, Injectable } from '@nestjs/common';
import * as config from '@nestjs/config';
import {PassportStrategy} from '@nestjs/passport';
import {ExtractJwt, Strategy} from 'passport-jwt';

import {JwtPayload} from '../types/jwt-payload.type';
import {jwtConfig} from '../../config';

/**
 * Passport JWT strategy for **access tokens**.
 *
 * Extracts the Bearer token from the `Authorization` header and verifies
 * the signature against `jwt.accessSecret` from the typed configuration
 * namespace. On success, Passport attaches the decoded payload to
 * `request.user`.
 *
 * Used by the global {@link JwtAuthGuard} to protect all non-public routes.
 *
 * OWASP A07: access tokens are short-lived (default 15 minutes). A
 * compromised token cannot be revoked before expiry, but its brief
 * lifetime limits the exposure window. Distinguish from the refresh
 * strategy, which uses a separate secret.
 */
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    @Inject(jwtConfig.KEY)
    private readonly jwt: config.ConfigType<typeof jwtConfig>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: jwt.accessSecret,
    });
  }

  /**
   * Called by Passport after signature and expiry verification.
   *
   * Returns only the fields that route handlers need via `@CurrentUser()`.
   * Returning the full raw payload is intentionally avoided to control
   * what lands in `request.user` (OWASP A09).
   */
  validate(payload: JwtPayload): JwtPayload {
    return { sub: payload.sub, email: payload.email };
  }
}