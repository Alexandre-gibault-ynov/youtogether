import {
  IsEmail,
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

/**
 * Validated request body for `POST /auth/register`.
 *
 * class-validator enforces constraints that mirror those defined in the
 * data model and the Flutter-side
 * form validation, providing a consistent second line of defense
 * (OWASP A03 / A07).
 */
export class RegisterDto {
  /**
   * User email address — used as the login credential.
   *
   * Normalised to lowercase to prevent duplicate accounts via case
   * variation (e.g., Alice@example.com vs alice@example.com).
   */
  @ApiProperty({
    description: 'User email address. Used as the login credential. Normalised to lowercase.',
    example: 'alice@example.com',
    maxLength: 255,
  })
  @IsEmail({}, { message: 'email must be a valid email address.' })
  @MaxLength(255)
  @Transform(({ value }: { value: string }) => value?.toLowerCase().trim())
  email: string;

  /**
   * Plain-text password — bcrypt-hashed by AuthService before persistence.
   *
   * Minimum 8 characters mirrors the Flutter RegisterPage validator.
   * Maximum 72 characters aligns with bcrypt's effective key length.
   */
  @ApiProperty({
    description: 'Plain-text password. Hashed with bcrypt (12 rounds) before persistence.',
    example: 's3cur3P@ssword!',
    minLength: 8,
    maxLength: 72,
  })
  @IsString()
  @MinLength(8, { message: 'password must be at least 8 characters.' })
  @MaxLength(72, { message: 'password must be at most 72 characters.' })
  @IsNotEmpty()
  password: string;

  /**
   * Display name shown in the UI and within room sessions.
   *
   * Length constraints mirror the `username` column definition (VARCHAR 50).
   */
  @ApiProperty({
    description: 'Display name shown in the UI and within room sessions.',
    example: 'Alice',
    minLength: 3,
    maxLength: 50,
  })
  @IsString()
  @MinLength(3, { message: 'username must be at least 3 characters.' })
  @MaxLength(50, { message: 'username must be at most 50 characters.' })
  @IsNotEmpty()
  @Transform(({ value }: { value: string }) => value?.trim())
  username: string;
}