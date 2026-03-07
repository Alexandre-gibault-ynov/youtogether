import { jwtConfig } from '../../../src/config';

/**
 * The factory returned by `registerAs` is accessible at `jwtConfig()`.
 * We test it directly, resetting `process.env` between each case.
 */
describe('jwtConfig', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('returns correct values when all environment variables are set', () => {
    process.env['JWT_ACCESS_SECRET'] = 'access-secret-32chars-minimum!!';
    process.env['JWT_REFRESH_SECRET'] = 'refresh-secret-32chars-minimum!';
    process.env['JWT_ACCESS_EXPIRES_IN'] = '30m';
    process.env['JWT_REFRESH_EXPIRES_IN'] = '14d';

    const config = jwtConfig();

    expect(config.accessSecret).toBe('access-secret-32chars-minimum!!');
    expect(config.refreshSecret).toBe('refresh-secret-32chars-minimum!');
    expect(config.accessExpiresIn).toBe('30m');
    expect(config.refreshExpiresIn).toBe('14d');
  });

  it('uses default TTLs when JWT_ACCESS_EXPIRES_IN and JWT_REFRESH_EXPIRES_IN are absent', () => {
    process.env['JWT_ACCESS_SECRET'] = 'access-secret';
    process.env['JWT_REFRESH_SECRET'] = 'refresh-secret';
    delete process.env['JWT_ACCESS_EXPIRES_IN'];
    delete process.env['JWT_REFRESH_EXPIRES_IN'];

    const config = jwtConfig();

    expect(config.accessExpiresIn).toBe('15m');
    expect(config.refreshExpiresIn).toBe('7d');
  });

  it('throws when JWT_ACCESS_SECRET is absent', () => {
    delete process.env['JWT_ACCESS_SECRET'];
    process.env['JWT_REFRESH_SECRET'] = 'refresh-secret';

    expect(() => jwtConfig()).toThrow('JWT_ACCESS_SECRET environment variable is required.');
  });

  it('throws when JWT_REFRESH_SECRET is absent', () => {
    process.env['JWT_ACCESS_SECRET'] = 'access-secret';
    delete process.env['JWT_REFRESH_SECRET'];

    expect(() => jwtConfig()).toThrow('JWT_REFRESH_SECRET environment variable is required.');
  });
});