import {
  Column,
  CreateDateColumn,
  DeleteDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * Allowed roles for a registered user.
 *
 * - `registered`: fully authenticated user with write capabilities.
 * - `guest`: unauthenticated visitor with read-only access.
 *
 * Maps to the PostgreSQL ENUM constraint defined in the data model.
 */
export enum UserRole {
  REGISTERED = 'registered',
  GUEST = 'guest',
}

/**
 * Persistent representation of the User aggregate root.
 *
 * Schema decisions (aligned with YouTogether_DataModel.docx §2.1.1):
 * - `password_hash` stores a bcrypt digest — never plain text.
 * - `refresh_token_hash` stores a bcrypt digest of the current refresh
 *   token; set to NULL on logout to invalidate the token server-side.
 * - `deleted_at` supports soft deletion, preserving referential
 *   integrity with historical room membership records (OWASP A04).
 *
 * OWASP A02: No plain-text credentials appear in any column.
 * OWASP A09: TypeORM timestamps enable audit log reconstruction.
 */
@Entity('users')
export class UserEntity {
  /** Universally unique identifier (UUID v4). */
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /**
   * User email address used as the login credential.
   * Unique constraint prevents duplicate accounts (maps to HTTP 409 on register).
   */
  @Column({ type: 'varchar', length: 255, unique: true })
  email: string;

  /**
   * bcrypt hash of the user password.
   *
   * The `select: false` option prevents the column from being included
   * in query results by default, reducing the surface area for
   * accidental credential exposure (OWASP A02).
   */
  @Column({ name: 'password_hash', type: 'varchar', length: 255, select: false })
  passwordHash: string;

  /** Display name shown in the UI and within room sessions. */
  @Column({ type: 'varchar', length: 50 })
  username: string;

  /**
   * User role — `registered` or `guest`.
   * Defaults to `registered` at account creation.
   */
  @Column({
    type: 'enum',
    enum: UserRole,
    default: UserRole.REGISTERED,
  })
  role: UserRole;

  /**
   * bcrypt hash of the current refresh token.
   *
   * Set to NULL on logout, invalidating the token server-side.
   * Token rotation replaces this value on every successful refresh
   * (OWASP A07).
   */
  @Column({
    name: 'refresh_token_hash',
    type: 'varchar',
    length: 255,
    nullable: true,
    select: false,
  })
  refreshTokenHash: string | null;

  /** UTC timestamp of account creation. */
  @CreateDateColumn({ name: 'created_at', type: 'timestamp' })
  createdAt: Date;

  /** UTC timestamp of last profile modification. */
  @UpdateDateColumn({ name: 'updated_at', type: 'timestamp' })
  updatedAt: Date;

  /**
   * Soft-delete timestamp.
   *
   * NULL when the account is active. Set by TypeORM's `softRemove()`.
   * Soft deletion preserves referential integrity with historical room
   * membership records (OWASP A04).
   */
  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamp', nullable: true })
  deletedAt: Date | null;
}