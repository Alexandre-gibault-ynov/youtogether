import { ConflictException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';

import { AuthController } from '../../src/auth/auth.controller';
import { AuthService } from '../../src/auth/auth.service';
import { AuthResponseDto, MeResponseDto } from '../../src/auth/dto/auth-response.dto';
import { RegisterDto } from '../../src/auth/dto/register.dto';
import { UserEntity, UserRole } from '../../src/users/entities/user.entity';
import { JwtPayload } from '../../src/auth/types/jwt-payload.type';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

const mockAuthService = {
  register: jest.fn(),
  login: jest.fn(),
  logout: jest.fn(),
  refreshTokens: jest.fn(),
  getMe: jest.fn(),
};

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function buildUser(): UserEntity {
  const user = new UserEntity();
  user.id = '00000000-0000-0000-0000-000000000001';
  user.email = 'alice@example.com';
  user.username = 'Alice';
  user.role = UserRole.REGISTERED;
  user.createdAt = new Date('2025-01-01T00:00:00Z');
  user.updatedAt = new Date('2025-01-01T00:00:00Z');
  user.deletedAt = null;
  return user;
}

function buildAuthResponse(): AuthResponseDto {
  const dto = new AuthResponseDto();
  dto.id = '00000000-0000-0000-0000-000000000001';
  dto.email = 'alice@example.com';
  dto.username = 'Alice';
  dto.role = UserRole.REGISTERED;
  dto.avatar_url = null;
  dto.created_at = new Date('2025-01-01T00:00:00Z');
  dto.access_token = 'mock.access.token';
  dto.refresh_token = 'mock.refresh.token';
  return dto;
}

function buildMeResponse(): MeResponseDto {
  const dto = new MeResponseDto();
  dto.id = '00000000-0000-0000-0000-000000000001';
  dto.email = 'alice@example.com';
  dto.username = 'Alice';
  dto.role = UserRole.REGISTERED;
  dto.avatar_url = null;
  dto.created_at = new Date('2025-01-01T00:00:00Z');
  return dto;
}

const tJwtPayload: JwtPayload = {
  sub: '00000000-0000-0000-0000-000000000001',
  email: 'alice@example.com',
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AuthController', () => {
  let controller: AuthController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: mockAuthService }],
    }).compile();

    controller = module.get<AuthController>(AuthController);
    jest.clearAllMocks();
  });

  // ── register ───────────────────────────────────────────────────────────────

  describe('POST /auth/register', () => {
    const dto: RegisterDto = {
      email: 'alice@example.com',
      password: 's3cur3P@ssword!',
      username: 'Alice',
    };

    it('returns AuthResponseDto when registration succeeds', async () => {
      // Arrange
      const expected = buildAuthResponse();
      mockAuthService.register.mockResolvedValue(expected);

      // Act
      const result = await controller.register(dto);

      // Assert
      expect(result).toEqual(expected);
      expect(mockAuthService.register).toHaveBeenCalledWith(dto);
    });

    it('propagates ConflictException (409) when email is already in use', async () => {
      // Arrange
      mockAuthService.register.mockRejectedValue(
        new ConflictException('An account with this email address already exists.'),
      );

      // Act & Assert
      await expect(controller.register(dto)).rejects.toThrow(ConflictException);
    });
  });

  // ── login ──────────────────────────────────────────────────────────────────

  describe('POST /auth/login', () => {
    it('returns AuthResponseDto for a request with a validated user', async () => {
      // Arrange
      const tUser = buildUser();
      const expected = buildAuthResponse();
      mockAuthService.login.mockResolvedValue(expected);
      const req = { user: tUser } as unknown as Parameters<typeof controller.login>[0];

      // Act
      const result = await controller.login(req);

      // Assert
      expect(result).toEqual(expected);
      expect(mockAuthService.login).toHaveBeenCalledWith(tUser);
    });
  });

  // ── logout ─────────────────────────────────────────────────────────────────

  describe('POST /auth/logout', () => {
    it('calls AuthService.logout with the current user id', async () => {
      // Arrange
      mockAuthService.logout.mockResolvedValue(undefined);

      // Act
      await controller.logout(tJwtPayload);

      // Assert
      expect(mockAuthService.logout).toHaveBeenCalledWith(tJwtPayload.sub);
    });

    it('returns void (no response body)', async () => {
      // Arrange
      mockAuthService.logout.mockResolvedValue(undefined);

      // Act
      const result = await controller.logout(tJwtPayload);

      // Assert
      expect(result).toBeUndefined();
    });
  });

  // ── refresh ────────────────────────────────────────────────────────────────

  describe('POST /auth/refresh', () => {
    it('returns a new AuthResponseDto when the refresh token is valid', async () => {
      // Arrange
      const expected = buildAuthResponse();
      mockAuthService.refreshTokens.mockResolvedValue(expected);
      const req = {
        user: { ...tJwtPayload, refreshToken: 'valid.refresh.token' },
      } as unknown as Parameters<typeof controller.refresh>[0];

      // Act
      const result = await controller.refresh(req);

      // Assert
      expect(result).toEqual(expected);
      expect(mockAuthService.refreshTokens).toHaveBeenCalledWith(
        tJwtPayload.sub,
        'valid.refresh.token',
      );
    });
  });

  // ── getMe ──────────────────────────────────────────────────────────────────

  describe('GET /auth/me', () => {
    it('returns MeResponseDto for the current authenticated user', async () => {
      // Arrange
      const expected = buildMeResponse();
      mockAuthService.getMe.mockResolvedValue(expected);

      // Act
      const result = await controller.getMe(tJwtPayload);

      // Assert
      expect(result).toEqual(expected);
      expect(mockAuthService.getMe).toHaveBeenCalledWith(tJwtPayload.sub);
    });

    it('does not include access_token or refresh_token in the response', async () => {
      // Arrange
      const expected = buildMeResponse();
      mockAuthService.getMe.mockResolvedValue(expected);

      // Act
      const result = await controller.getMe(tJwtPayload);

      // Assert
      expect((result as unknown as Record<string, unknown>)['access_token']).toBeUndefined();
      expect((result as unknown as Record<string, unknown>)['refresh_token']).toBeUndefined();
    });
  });
});