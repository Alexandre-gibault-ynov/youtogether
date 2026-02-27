import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy } from 'passport-local';

import { AuthService } from '../auth.service';
import { UserEntity } from '../../users/entities/user.entity';

/**
 * Passport Local strategy.
 *
 * Validates the `email` and `password` fields from the `POST /auth/login`
 * request body. Delegates credential verification to
 * {@link AuthService.validateLocalUser}.
 *
 * The `usernameField: 'email'` option overrides Passport's default
 * `username` field name to match the application's credential scheme.
 *
 * Used exclusively by {@link LocalAuthGuard}.
 */
@Injectable()
export class LocalStrategy extends PassportStrategy(Strategy, 'local') {
  constructor(private readonly authService: AuthService) {
    super({ usernameField: 'email' });
  }

  /**
   * Called by Passport before the route handler.
   *
   * Returns the validated {@link UserEntity} on success, which Passport
   * attaches to `request.user`.
   *
   * Throws {@link UnauthorizedException} (HTTP 401) when credentials are
   * invalid. The error message is deliberately generic to prevent user
   * enumeration (OWASP A07).
   */
  async validate(email: string, password: string): Promise<UserEntity> {
    const user = await this.authService.validateLocalUser(email, password);

    if (!user) {
      throw new UnauthorizedException('Invalid email or password.');
    }

    return user;
  }
}