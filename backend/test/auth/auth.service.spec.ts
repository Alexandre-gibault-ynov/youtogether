import { ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';

import { AuthService } from '../../src/auth/auth.service';
import { AuthResponseDto } from '../../src/auth/dto/auth-response.dto';
import { RegisterDto } from '../../src/auth/dto/register.dto';
import { UserEntity, UserRole } from '../../src/users/entities/user.entity';
import { UsersService } from '../../src/users/users.service';
import { jwtConfig } from '../../src/config';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

const mockUsersService = {
  create: jest.fn(),
  findByEmail: jest.fn(),
  findById: jest.fn(),
  updateRefreshTokenHash: jest.fn(),
};

const mockJwtService = {
  signAsync: jest.fn(),
};

/**
 * Typed mock for the jwt configuration namespace.
 *
 * Provided under the `jwtConfig.KEY` token to satisfy the
 * `@Inject(jwtConfig.KEY)` decorator in AuthService, replacing the
 * raw ConfigService that was used before the migration to typed namespaces.
 */
const mockJwtConfig = {
  accessSecret: 'test-access-secret',
  accessExpiresIn: '15m',
  refreshSecret: 'test-refresh-secret',
  refreshExpiresIn: '7d',
};

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function buildUser(overrides: Partial<UserEntity> = {}): UserEntity {
  const user = new UserEntity();
  user.id = '00000000-0000-0000-0000-000000000001';
  user.email = 'alice@example.com';
  user.username = 'Alice';
  user.role = UserRole.REGISTERED;
  user.passwordHash = '$2b$12$hashedpassword';
  user.refreshTokenHash = null;
  user.createdAt = new Date('2025-01-01T00:00:00Z');
  user.updatedAt = new Date('2025-01-01T00:00:00Z');
  user.deletedAt = null;
  return Object.assign(user, overrides);
}

const tUser = buildUser();

const tRegisterDto: RegisterDto = {
  email: 'alice@example.com',
  password: 's3cur3P@ssword!',
  username: 'Alice',
};

const ACCESS_TOKEN = 'mock.access.token';
const REFRESH_TOKEN = 'mock.refresh.token';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AuthService', () => {
  let authService: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: mockUsersService },
        { provide: JwtService, useValue: mockJwtService },
        { provide: jwtConfig.KEY, useValue: mockJwtConfig },
      ],
    }).compile();

    authService = module.get<AuthService>(AuthService);
    jest.clearAllMocks();
  });

  // ── register() ─────────────────────────────────────────────────────────────

  describe('register', () => {
    it('creates a user account and returns AuthResponseDto with tokens', async () => {
      // Arrange
      mockUsersService.create.mockResolvedValue(tUser);
      mockJwtService.signAsync
        .mockResolvedValueOnce(ACCESS_TOKEN)
        .mockResolvedValueOnce(REFRESH_TOKEN);
      mockUsersService.updateRefreshTokenHash.mockResolvedValue(undefined);

      // Act
      const result = await authService.register(tRegisterDto);

      // Assert
      expect(result).toBeInstanceOf(AuthResponseDto);
      expect(result.access_token).toBe(ACCESS_TOKEN);
      expect(result.refresh_token).toBe(REFRESH_TOKEN);
      expect(result.email).toBe(tUser.email);
      expect(mockUsersService.create).toHaveBeenCalledTimes(1);
      expect(mockUsersService.updateRefreshTokenHash).toHaveBeenCalledWith(
        tUser.id,
        expect.any(String),
      );
    });

    it('does not pass plain-text password to UsersService.create', async () => {
      // Arrange
      mockUsersService.create.mockResolvedValue(tUser);
      mockJwtService.signAsync
        .mockResolvedValueOnce(ACCESS_TOKEN)
        .mockResolvedValueOnce(REFRESH_TOKEN);
      mockUsersService.updateRefreshTokenHash.mockResolvedValue(undefined);

      // Act
      await authService.register(tRegisterDto);

      // Assert — passwordHash passed to create must not equal the plain password
      const [callArgs] = mockUsersService.create.mock.calls as [{ passwordHash: string }][];
      expect(callArgs[0].passwordHash).not.toBe(tRegisterDto.password);
      expect(callArgs[0].passwordHash).toMatch(/^\$2[ab]\$\d+\$/);
    });

    it('propagates ConflictException when email is already in use', async () => {
      // Arrange
      mockUsersService.create.mockRejectedValue(
        new ConflictException('An account with this email address already exists.'),
      );

      // Act & Assert
      await expect(authService.register(tRegisterDto)).rejects.toThrow(
        ConflictException,
      );
      expect(mockUsersService.updateRefreshTokenHash).not.toHaveBeenCalled();
    });
  });

  // ── validateLocalUser() ────────────────────────────────────────────────────

  describe('validateLocalUser', () => {
    it('returns the user when credentials are valid', async () => {
      // Arrange — create a real bcrypt hash to test actual comparison
      const plainPassword = 's3cur3P@ssword!';
      const hash = await bcrypt.hash(plainPassword, 10);
      const userWithHash = buildUser({ passwordHash: hash });
      mockUsersService.findByEmail.mockResolvedValue(userWithHash);

      // Act
      const result = await authService.validateLocalUser(
        'alice@example.com',
        plainPassword,
      );

      // Assert
      expect(result).toBeDefined();
      expect(result?.id).toBe(tUser.id);
    });

    it('returns null when the password is incorrect', async () => {
      // Arrange
      const hash = await bcrypt.hash('correct-password', 10);
      mockUsersService.findByEmail.mockResolvedValue(buildUser({ passwordHash: hash }));

      // Act
      const result = await authService.validateLocalUser(
        'alice@example.com',
        'wrong-password',
      );

      // Assert
      expect(result).toBeNull();
    });

    it('returns null when the email is not registered', async () => {
      // Arrange
      mockUsersService.findByEmail.mockResolvedValue(null);

      // Act
      const result = await authService.validateLocalUser(
        'unknown@example.com',
        'anypassword',
      );

      // Assert
      expect(result).toBeNull();
    });
  });

  // ── login() ────────────────────────────────────────────────────────────────

  describe('login', () => {
    it('issues a token pair for a validated user', async () => {
      // Arrange
      mockJwtService.signAsync
        .mockResolvedValueOnce(ACCESS_TOKEN)
        .mockResolvedValueOnce(REFRESH_TOKEN);
      mockUsersService.updateRefreshTokenHash.mockResolvedValue(undefined);

      // Act
      const result = await authService.login(tUser);

      // Assert
      expect(result.access_token).toBe(ACCESS_TOKEN);
      expect(result.refresh_token).toBe(REFRESH_TOKEN);
      expect(mockUsersService.updateRefreshTokenHash).toHaveBeenCalledWith(
        tUser.id,
        expect.any(String), // bcrypt hash of the refresh token
      );
    });
  });

  // ── logout() ───────────────────────────────────────────────────────────────

  describe('logout', () => {
    it('sets refresh_token_hash to null for the given user', async () => {
      // Arrange
      mockUsersService.updateRefreshTokenHash.mockResolvedValue(undefined);

      // Act
      await authService.logout(tUser.id);

      // Assert
      expect(mockUsersService.updateRefreshTokenHash).toHaveBeenCalledWith(
        tUser.id,
        null,
      );
      expect(mockUsersService.updateRefreshTokenHash).toHaveBeenCalledTimes(1);
    });
  });

  // ── refreshTokens() ────────────────────────────────────────────────────────

  describe('refreshTokens', () => {
    it('returns a new token pair when the refresh token is valid', async () => {
      // Arrange — store a real bcrypt hash to simulate a live refresh token
      const rawToken = 'valid.refresh.token';
      const storedHash = await bcrypt.hash(rawToken, 10);
      mockUsersService.findById.mockResolvedValue(
        buildUser({ refreshTokenHash: storedHash }),
      );
      mockJwtService.signAsync
        .mockResolvedValueOnce('new.access.token')
        .mockResolvedValueOnce('new.refresh.token');
      mockUsersService.updateRefreshTokenHash.mockResolvedValue(undefined);

      // Act
      const result = await authService.refreshTokens(tUser.id, rawToken);

      // Assert
      expect(result.access_token).toBe('new.access.token');
      expect(result.refresh_token).toBe('new.refresh.token');
    });

    it('throws ForbiddenException when no session exists (null hash)', async () => {
      // Arrange
      mockUsersService.findById.mockResolvedValue(
        buildUser({ refreshTokenHash: null }),
      );

      // Act & Assert
      await expect(
        authService.refreshTokens(tUser.id, 'any.token'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('throws ForbiddenException and invalidates session on token mismatch', async () => {
      // Arrange — hash does not match the provided raw token
      const storedHash = await bcrypt.hash('different.token', 10);
      mockUsersService.findById.mockResolvedValue(
        buildUser({ refreshTokenHash: storedHash }),
      );
      mockUsersService.updateRefreshTokenHash.mockResolvedValue(undefined);

      // Act & Assert
      await expect(
        authService.refreshTokens(tUser.id, 'wrong.token'),
      ).rejects.toThrow(ForbiddenException);

      // Session must be invalidated to prevent further reuse attempts
      expect(mockUsersService.updateRefreshTokenHash).toHaveBeenCalledWith(
        tUser.id,
        null,
      );
    });
  });

  // ── getMe() ────────────────────────────────────────────────────────────────

  describe('getMe', () => {
    it('returns MeResponseDto without tokens or credential fields', async () => {
      // Arrange
      mockUsersService.findById.mockResolvedValue(tUser);

      // Act
      const result = await authService.getMe(tUser.id);

      // Assert
      expect(result.id).toBe(tUser.id);
      expect(result.email).toBe(tUser.email);
      expect((result as unknown as Record<string, unknown>)['access_token']).toBeUndefined();
      expect((result as unknown as Record<string, unknown>)['refresh_token']).toBeUndefined();
      expect((result as unknown as Record<string, unknown>)['passwordHash']).toBeUndefined();
    });

    it('propagates NotFoundException when user does not exist', async () => {
      // Arrange
      mockUsersService.findById.mockRejectedValue(
        new NotFoundException('User not found.'),
      );

      // Act & Assert
      await expect(authService.getMe('nonexistent-id')).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});