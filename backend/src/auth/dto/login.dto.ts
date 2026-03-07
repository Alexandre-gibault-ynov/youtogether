import { IsEmail, IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { Transform } from 'class-transformer';

/**
 * Validated request body for `POST /auth/login`.
 */
export class LoginDto {
  /** User email address. Normalised to lowercase before lookup. */
  @IsEmail({}, { message: 'email must be a valid email address.' })
  @MaxLength(255)
  @Transform(({ value }: { value: string }) => value?.toLowerCase().trim())
  email: string;

  /** Plain-text password — compared against the stored bcrypt hash. */
  @IsString()
  @IsNotEmpty({ message: 'password is required.' })
  password: string;
}