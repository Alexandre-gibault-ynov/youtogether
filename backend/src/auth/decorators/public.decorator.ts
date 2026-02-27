import { SetMetadata } from '@nestjs/common';

/**
 * Metadata key consumed by {@link JwtAuthGuard}.
 */
export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Marks a route handler as publicly accessible.
 *
 * Routes decorated with `@Public()` bypass the global {@link JwtAuthGuard}.
 * Apply to endpoints that must be reachable without an access token:
 * `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`.
 *
 * @example
 * ```TypeScript
 * @Public()
 * @Post('login')
 * login(@Body() dto: LoginDto) { ... }
 * ```
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);