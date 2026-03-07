import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';

import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

/**
 * Guard for `POST /auth/login`.
 *
 * Invokes the Passport Local strategy, which validates the email/password
 * pair and attaches the validated {@link UserEntity} to `request.user`.
 */
@Injectable()
export class LocalAuthGuard extends AuthGuard('local') {}

/**
 * Global JWT guard that protects all routes by default.
 *
 * Routes decorated with {@link Public} bypass this guard. All other
 * routes require a valid `Authorization: Bearer <access_token>` header.
 *
 * Applied globally in {@link AuthModule} to avoid decorator repetition
 * and to ensure security-by-default (OWASP A07).
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  /**
   * Bypasses the guard when the route is decorated with `@Public()`.
   * Otherwise delegates to Passport JWT strategy verification.
   */
  canActivate(context: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    return super.canActivate(context);
  }

  handleRequest<TUser>(
    err: Error | null,
    user: TUser | false,
  ): TUser {
    if (err || !user) {
      throw err ?? new UnauthorizedException('Access token is missing or invalid.');
    }
    return user;
  }
}

/**
 * Guard for `POST /auth/refresh`.
 *
 * Invokes the Passport JWT-Refresh strategy, which validates the refresh
 * token and passes the raw token string through to `AuthService` for
 * hash comparison (OWASP A07 — token rotation).
 */
@Injectable()
export class JwtRefreshGuard extends AuthGuard('jwt-refresh') {}