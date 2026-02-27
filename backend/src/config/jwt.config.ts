import { registerAs } from '@nestjs/config';

/**
 * Typed contract for JWT configuration values.
 *
 * Both access and refresh tokens use distinct secrets and expiry windows.
 * This separation prevents a leaked access token from being accepted as
 * a refresh token and vice versa (OWASP A07).
 */
export interface JwtConfig {
  /** Secret used to sign and verify access tokens. Minimum 32 characters. */
  accessSecret: string;

  /** Access token TTL — short-lived (default 15m). */
  accessExpiresIn: string;

  /** Secret used to sign and verify refresh tokens. Must differ from accessSecret. */
  refreshSecret: string;

  /** Refresh token TTL — long-lived (default 7d). */
  refreshExpiresIn: string;
}

/**
 * Registers the `jwt` configuration namespace.
 *
 * Consumed via `@Inject(jwtConfig.KEY)` with `ConfigType<typeof jwtConfig>`
 * for full TypeScript inference, eliminating raw `configService.get('JWT_*')`
 * string lookups across the codebase.
 *
 * @throws {Error} at startup if `JWT_ACCESS_SECRET` or `JWT_REFRESH_SECRET`
 *   are absent — intentional fail-fast to prevent launching with insecure
 *   defaults.
 */
export const jwtConfig = registerAs('jwt', (): JwtConfig => {
  const accessSecret = process.env['JWT_ACCESS_SECRET'];
  const refreshSecret = process.env['JWT_REFRESH_SECRET'];

  if (!accessSecret) {
    throw new Error('JWT_ACCESS_SECRET environment variable is required.');
  }
  if (!refreshSecret) {
    throw new Error('JWT_REFRESH_SECRET environment variable is required.');
  }

  return {
    accessSecret,
    accessExpiresIn: process.env['JWT_ACCESS_EXPIRES_IN'] ?? '15m',
    refreshSecret,
    refreshExpiresIn: process.env['JWT_REFRESH_EXPIRES_IN'] ?? '7d',
  };
});