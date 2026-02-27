import { ApiProperty } from '@nestjs/swagger';

/**
 * Swagger schema class mirroring {@link ErrorResponseBody}.
 *
 * Used exclusively as an `@ApiResponse({ type: ... })` argument so that
 * Swagger UI displays the normalised error envelope for every endpoint.
 * It is never instantiated at runtime.
 */
export class ApiErrorResponseDto {
  @ApiProperty({ example: 401 })
  statusCode: number;

  @ApiProperty({ example: 'Unauthorized' })
  error: string;

  @ApiProperty({ example: 'Access token is missing or invalid.' })
  message: string;

  @ApiProperty({
    example: null,
    nullable: true,
    description:
      'Field-keyed validation errors. Populated only for HTTP 422; null otherwise.',
    type: 'object',
    additionalProperties: { type: 'string' },
  })
  errors: Record<string, string> | null;

  @ApiProperty({ example: '2026-02-27T14:32:00.000Z' })
  timestamp: string;

  @ApiProperty({ example: '/api/auth/me' })
  path: string;
}

/**
 * Swagger schema for HTTP 422 Unprocessable Entity.
 *
 * Extends the base error schema to show a concrete `errors` map example.
 */
export class ApiValidationErrorDto extends ApiErrorResponseDto {
  @ApiProperty({ example: 422 })
  declare statusCode: number;

  @ApiProperty({ example: 'Unprocessable Entity' })
  declare error: string;

  @ApiProperty({ example: 'Validation failed.' })
  declare message: string;

  @ApiProperty({
    example: {
      email: 'email must be a valid email address.',
      password: 'password must be at least 8 characters.',
    },
    nullable: false,
    type: 'object',
    additionalProperties: { type: 'string' },
  })
  declare errors: Record<string, string>;
}