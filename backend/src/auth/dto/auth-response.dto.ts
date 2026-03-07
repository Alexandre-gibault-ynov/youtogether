import { ApiProperty } from '@nestjs/swagger';
import { UserEntity } from '../../users/entities/user.entity';

/**
 * Response payload for all endpoints that return an authenticated
 * session: `POST /auth/register`, `POST /auth/login`, and
 * `POST /auth/refresh`.
 *
 * Field names use snake_case to align with the Flutter `UserModel`
 * JSON contract defined in `YouTogether_Interface_Contracts_v1.1.docx`.
 */
export class AuthResponseDto {
  @ApiProperty({ example: '3fa85f64-5717-4562-b3fc-2c963f66afa6' })
  id: string;

  @ApiProperty({ example: 'alice@example.com' })
  email: string;

  @ApiProperty({ example: 'Alice' })
  username: string;

  @ApiProperty({ example: 'registered', enum: ['registered', 'guest'] })
  role: string;

  @ApiProperty({ example: null, nullable: true })
  avatar_url: string | null;

  @ApiProperty({ example: '2026-02-27T12:00:00.000Z' })
  created_at: Date;

  /** Short-lived JWT — expires in `JWT_ACCESS_EXPIRES_IN` (default 15m). */
  @ApiProperty({
    description: 'Short-lived JWT access token (default TTL: 15 minutes). Pass as Authorization: Bearer <token>.',
    example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmE4NWY2NC01NzE3LTQ1NjItYjNmYy0yYzk2M2Y2NmFmYTYiLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwiaWF0IjoxNzA5MDMwNDAwLCJleHAiOjE3MDkwMzEzMDB9.signature',
  })
  access_token: string;

  /** Long-lived refresh token — expires in `JWT_REFRESH_EXPIRES_IN` (default 7d). */
  @ApiProperty({
    description: 'Long-lived refresh token (default TTL: 7 days). Pass as Authorization: Bearer <token> to POST /auth/refresh.',
    example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmE4NWY2NC01NzE3LTQ1NjItYjNmYy0yYzk2M2Y2NmFmYTYiLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwiaWF0IjoxNzA5MDMwNDAwLCJleHAiOjE3MDk2MzUyMDB9.signature',
  })
  refresh_token: string;

  /**
   * Maps a {@link UserEntity} and a token pair to the response DTO.
   *
   * Keeps the controller free of mapping logic and ensures the response
   * shape never inadvertently includes `passwordHash` or
   * `refreshTokenHash`.
   */
  static from(
    user: UserEntity,
    accessToken: string,
    refreshToken: string,
  ): AuthResponseDto {
    const dto = new AuthResponseDto();
    dto.id = user.id;
    dto.email = user.email;
    dto.username = user.username;
    dto.role = user.role;
    dto.avatar_url = null;
    dto.created_at = user.createdAt;
    dto.access_token = accessToken;
    dto.refresh_token = refreshToken;
    return dto;
  }
}

/**
 * Response payload for `GET /auth/me`.
 *
 * No tokens are re-issued on this endpoint; the shape aligns with the
 * Flutter `UserModel` fields where `access_token` and `refresh_token`
 * are nullable.
 */
export class MeResponseDto {
  @ApiProperty({ example: '3fa85f64-5717-4562-b3fc-2c963f66afa6' })
  id: string;

  @ApiProperty({ example: 'alice@example.com' })
  email: string;

  @ApiProperty({ example: 'Alice' })
  username: string;

  @ApiProperty({ example: 'registered', enum: ['registered', 'guest'] })
  role: string;

  @ApiProperty({ example: null, nullable: true })
  avatar_url: string | null;

  @ApiProperty({ example: '2026-02-27T12:00:00.000Z' })
  created_at: Date;

  static from(user: UserEntity): MeResponseDto {
    const dto = new MeResponseDto();
    dto.id = user.id;
    dto.email = user.email;
    dto.username = user.username;
    dto.role = user.role;
    dto.avatar_url = null;
    dto.created_at = user.createdAt;
    return dto;
  }
}