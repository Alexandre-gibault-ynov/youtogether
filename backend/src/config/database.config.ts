import { registerAs } from '@nestjs/config';

/**
 * Typed contract for PostgreSQL connection configuration.
 */
export interface DatabaseConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  name: string;

  /**
   * When true, TypeORM synchronises the schema on startup.
   *
   * Must be `false` in production — schema changes should go through
   * migrations to avoid accidental data loss (OWASP A05).
   */
  synchronize: boolean;

  /** Enables TypeORM query logging in development. */
  logging: boolean;
}

/**
 * Registers the `database` configuration namespace.
 *
 * @throws {Error} at startup when any required PostgreSQL variable is absent.
 */
export const databaseConfig = registerAs('database', (): DatabaseConfig => {
  const required: Record<string, string | undefined> = {
    DB_HOST: process.env['DB_HOST'],
    DB_USERNAME: process.env['DB_USERNAME'],
    DB_PASSWORD: process.env['DB_PASSWORD'],
    DB_NAME: process.env['DB_NAME'],
  };

  for (const [key, value] of Object.entries(required)) {
    if (!value) {
      throw new Error(`${key} environment variable is required.`);
    }
  }

  const isProduction = process.env['NODE_ENV'] === 'production';

  return {
    host: required['DB_HOST'] as string,
    port: parseInt(process.env['DB_PORT'] ?? '5432', 10),
    username: required['DB_USERNAME'] as string,
    password: required['DB_PASSWORD'] as string,
    name: required['DB_NAME'] as string,
    synchronize: !isProduction,
    logging: process.env['NODE_ENV'] === 'development',
  };
});