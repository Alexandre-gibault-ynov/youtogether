import { registerAs } from '@nestjs/config';

/**
 * Typed contract for general application settings.
 */
export interface AppConfig {
  port: number;
  nodeEnv: 'development' | 'production' | 'test';
  corsOrigin: string;
}

/**
 * Registers the `app` configuration namespace.
 */
export const appConfig = registerAs('app', (): AppConfig => {
  const nodeEnv = (process.env['NODE_ENV'] ?? 'development') as AppConfig['nodeEnv'];

  return {
    port: parseInt(process.env['PORT'] ?? '3000', 10),
    nodeEnv,
    corsOrigin: process.env['CORS_ORIGIN'] ?? '*',
  };
});