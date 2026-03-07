/**
 * Barrel export for all typed configuration namespaces.
 *
 * Import from this path in AppModule:
 * ```TypeScript
 * import { appConfig, databaseConfig, jwtConfig } from './config';
 * ```
 */
export { appConfig } from './app.config';
export type { AppConfig } from './app.config';

export { databaseConfig } from './database.config';
export type { DatabaseConfig } from './database.config';

export { jwtConfig } from './jwt.config';
export type { JwtConfig } from './jwt.config';