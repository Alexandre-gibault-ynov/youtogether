import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { UserEntity, UserRole } from './entities/user.entity';

/**
 * Input parameters for creating a new user account.
 *
 * The `passwordHash` field must already be a bcrypt digest produced by
 * the caller (AuthService). UsersService never receives plain-text passwords.
 */
export interface CreateUserParams {
  email: string;
  passwordHash: string;
  username: string;
  role?: UserRole;
}

/**
 * Service responsible for all persistent User operations.
 *
 * AuthService delegates to UsersService for every database interaction
 * that concerns users. No authentication logic lives here.
 *
 * OWASP A03: all queries are parameterised via TypeORM — no raw SQL
 * string concatenation is used.
 */
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepository: Repository<UserEntity>,
  ) {}

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /**
   * Persists a new user record.
   *
   * Throws {@link ConflictException} (HTTP 409) when the email is already
   * registered — this maps to `ValidationFailure { email: ... }` on the
   * Flutter client.
   */
  async create(params: CreateUserParams): Promise<UserEntity> {
    const existing = await this.userRepository.findOne({
      where: { email: params.email.toLowerCase() },
      withDeleted: true, // also check soft-deleted accounts
    });

    if (existing) {
      throw new ConflictException(
        'An account with this email address already exists.',
      );
    }

    const user = this.userRepository.create({
      email: params.email.toLowerCase(),
      passwordHash: params.passwordHash,
      username: params.username,
      role: params.role ?? UserRole.REGISTERED,
    });

    return this.userRepository.save(user);
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /**
   * Returns a user by email.
   *
   * Includes `passwordHash` (normally excluded by `select: false`) when
   * `includePasswordHash` is true — required exclusively during login
   * credential validation.
   */
  async findByEmail(
    email: string,
    includePasswordHash = false,
  ): Promise<UserEntity | null> {
    const qb = this.userRepository
      .createQueryBuilder('user')
      .where('user.email = :email', { email: email.toLowerCase() });

    if (includePasswordHash) {
      qb.addSelect('user.passwordHash');
    }

    return qb.getOne();
  }

  /**
   * Returns a user by its UUID primary key.
   *
   * Throws {@link NotFoundException} (HTTP 404) when no record is found.
   *
   * `includeRefreshTokenHash` selects the normally-hidden column required
   * for refresh token validation.
   */
  async findById(
    id: string,
    includeRefreshTokenHash = false,
  ): Promise<UserEntity> {
    const qb = this.userRepository
      .createQueryBuilder('user')
      .where('user.id = :id', { id });

    if (includeRefreshTokenHash) {
      qb.addSelect('user.refreshTokenHash');
    }

    const user = await qb.getOne();

    if (!user) {
      throw new NotFoundException(`User ${id} not found.`);
    }

    return user;
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /**
   * Persists a new `refresh_token_hash` for the given user.
   *
   * Accepts NULL to invalidate the token on logout (OWASP A07).
   */
  async updateRefreshTokenHash(
    userId: string,
    hash: string | null,
  ): Promise<void> {
    await this.userRepository.update({ id: userId }, { refreshTokenHash: hash });
  }
}