import { ConflictException, NotFoundException } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test, TestingModule } from '@nestjs/testing';

import { UsersService } from '../../src/users/users.service';
import { UserEntity, UserRole } from '../../src/users/entities/user.entity';

// ---------------------------------------------------------------------------
// Repository mock
// ---------------------------------------------------------------------------

const mockRepository = {
  findOne: jest.fn(),
  create: jest.fn(),
  save: jest.fn(),
  update: jest.fn(),
  createQueryBuilder: jest.fn(),
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

// Helper to build a chainable QueryBuilder mock
function buildQbMock(returnValue: UserEntity | null) {
  const qb = {
    where: jest.fn().mockReturnThis(),
    addSelect: jest.fn().mockReturnThis(),
    getOne: jest.fn().mockResolvedValue(returnValue),
  };
  mockRepository.createQueryBuilder.mockReturnValue(qb);
  return qb;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('UsersService', () => {
  let service: UsersService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(UserEntity),
          useValue: mockRepository,
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    jest.clearAllMocks();
  });

  // ── create() ───────────────────────────────────────────────────────────────

  describe('create', () => {
    it('creates and returns a new UserEntity when email is unique', async () => {
      // Arrange
      mockRepository.findOne.mockResolvedValue(null);
      mockRepository.create.mockReturnValue(tUser);
      mockRepository.save.mockResolvedValue(tUser);

      // Act
      const result = await service.create({
        email: 'alice@example.com',
        passwordHash: '$2b$12$hash',
        username: 'Alice',
      });

      // Assert
      expect(result).toEqual(tUser);
      expect(mockRepository.save).toHaveBeenCalledTimes(1);
    });

    it('normalises the email to lowercase before checking uniqueness', async () => {
      // Arrange
      mockRepository.findOne.mockResolvedValue(null);
      mockRepository.create.mockReturnValue(tUser);
      mockRepository.save.mockResolvedValue(tUser);

      // Act
      await service.create({
        email: 'Alice@Example.COM',
        passwordHash: '$2b$12$hash',
        username: 'Alice',
      });

      // Assert — findOne called with lowercase email
      expect(mockRepository.findOne).toHaveBeenCalledWith(
        expect.objectContaining({ where: { email: 'alice@example.com' } }),
      );
    });

    it('throws ConflictException (409) when email is already in use', async () => {
      // Arrange
      mockRepository.findOne.mockResolvedValue(tUser);

      // Act & Assert
      await expect(
        service.create({
          email: 'alice@example.com',
          passwordHash: '$2b$12$hash',
          username: 'Alice',
        }),
      ).rejects.toThrow(ConflictException);

      expect(mockRepository.save).not.toHaveBeenCalled();
    });
  });

  // ── findByEmail() ──────────────────────────────────────────────────────────

  describe('findByEmail', () => {
    it('returns a user when the email exists', async () => {
      // Arrange
      buildQbMock(tUser);

      // Act
      const result = await service.findByEmail('alice@example.com');

      // Assert
      expect(result).toEqual(tUser);
    });

    it('returns null when the email is not registered', async () => {
      // Arrange
      buildQbMock(null);

      // Act
      const result = await service.findByEmail('unknown@example.com');

      // Assert
      expect(result).toBeNull();
    });

    it('includes passwordHash column when includePasswordHash is true', async () => {
      // Arrange
      const qb = buildQbMock(tUser);

      // Act
      await service.findByEmail('alice@example.com', true);

      // Assert — addSelect must be called to override select: false
      expect(qb.addSelect).toHaveBeenCalledWith('user.passwordHash');
    });

    it('does not include passwordHash column by default', async () => {
      // Arrange
      const qb = buildQbMock(tUser);

      // Act
      await service.findByEmail('alice@example.com');

      // Assert
      expect(qb.addSelect).not.toHaveBeenCalled();
    });
  });

  // ── findById() ─────────────────────────────────────────────────────────────

  describe('findById', () => {
    it('returns the user when the id exists', async () => {
      // Arrange
      buildQbMock(tUser);

      // Act
      const result = await service.findById(tUser.id);

      // Assert
      expect(result).toEqual(tUser);
    });

    it('throws NotFoundException (404) when the id does not exist', async () => {
      // Arrange
      buildQbMock(null);

      // Act & Assert
      await expect(service.findById('nonexistent-id')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('includes refreshTokenHash when includeRefreshTokenHash is true', async () => {
      // Arrange
      const qb = buildQbMock(tUser);

      // Act
      await service.findById(tUser.id, true);

      // Assert
      expect(qb.addSelect).toHaveBeenCalledWith('user.refreshTokenHash');
    });
  });

  // ── updateRefreshTokenHash() ───────────────────────────────────────────────

  describe('updateRefreshTokenHash', () => {
    it('updates the refresh_token_hash to a new hash value', async () => {
      // Arrange
      mockRepository.update.mockResolvedValue({ affected: 1 });

      // Act
      await service.updateRefreshTokenHash(tUser.id, 'new-hash');

      // Assert
      expect(mockRepository.update).toHaveBeenCalledWith(
        { id: tUser.id },
        { refreshTokenHash: 'new-hash' },
      );
    });

    it('sets refresh_token_hash to null on logout', async () => {
      // Arrange
      mockRepository.update.mockResolvedValue({ affected: 1 });

      // Act
      await service.updateRefreshTokenHash(tUser.id, null);

      // Assert
      expect(mockRepository.update).toHaveBeenCalledWith(
        { id: tUser.id },
        { refreshTokenHash: null },
      );
    });
  });
});