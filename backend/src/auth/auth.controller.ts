import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiBody,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Request as ExpressRequest } from 'express';

import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AuthResponseDto, MeResponseDto } from './dto/auth-response.dto';
import { LocalAuthGuard, JwtRefreshGuard } from './guards/auth.guards';
import { Public } from './decorators/public.decorator';
import { CurrentUser } from './decorators/current-user.decorator';
import type { JwtPayload } from './types/jwt-payload.type';
import { UserEntity } from '../users/entities/user.entity';
import {
  ApiErrorResponseDto,
  ApiValidationErrorDto,
} from '../common/dto/api-error-response.dto';

/**
 * REST controller for all authentication operations.
 *
 * Base path: `/auth`
 *
 * Endpoint mapping (aligned with IAuthRemoteDataSource contract):
 * | Method | Path           | Guard           | Description                    |
 * |--------|----------------|-----------------|--------------------------------|
 * | POST   | /auth/register | @Public         | Create account + issue tokens  |
 * | POST   | /auth/login    | LocalAuthGuard  | Validate credentials + tokens  |
 * | POST   | /auth/logout   | JwtAuthGuard    | Invalidate refresh token       |
 * | POST   | /auth/refresh  | JwtRefreshGuard | Rotate token pair              |
 * | GET    | /auth/me       | JwtAuthGuard    | Return current user profile    |
 *
 * Google OAuth2 (`POST /auth/google`) is reserved for a future iteration
 * and is not implemented here.
 */
@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // ---------------------------------------------------------------------------
  // POST /auth/register
  // ---------------------------------------------------------------------------

  @ApiOperation({
    summary: 'Register a new user account',
    description:
      'Creates a new user account with the provided credentials and returns a full session token pair (access + refresh). The password is bcrypt-hashed server-side; it is never persisted in plain text.',
  })
  @ApiBody({ type: RegisterDto })
  @ApiResponse({
    status: 201,
    description: 'Account created. Returns access and refresh tokens.',
    type: AuthResponseDto,
  })
  @ApiResponse({
    status: 409,
    description: 'Conflict — the email address is already registered.',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 422,
    description: 'Validation failure — one or more request fields are invalid.',
    type: ApiValidationErrorDto,
  })
  @Public()
  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  register(@Body() dto: RegisterDto): Promise<AuthResponseDto> {
    return this.authService.register(dto);
  }

  // ---------------------------------------------------------------------------
  // POST /auth/login
  // ---------------------------------------------------------------------------

  @ApiOperation({
    summary: 'Authenticate with email and password',
    description:
      'Validates the provided credentials against the stored bcrypt hash and returns a session token pair. A timing-safe dummy comparison is performed when the email does not exist to prevent user enumeration.',
  })
  @ApiBody({ type: LoginDto })
  @ApiResponse({
    status: 200,
    description: 'Authentication successful. Returns access and refresh tokens.',
    type: AuthResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized — invalid email or password.',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 422,
    description: 'Validation failure — request body is malformed.',
    type: ApiValidationErrorDto,
  })
  @Public()
  @UseGuards(LocalAuthGuard)
  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(
    @Request() req: ExpressRequest & { user: UserEntity },
  ): Promise<AuthResponseDto> {
    return this.authService.login(req.user);
  }

  // ---------------------------------------------------------------------------
  // POST /auth/logout
  // ---------------------------------------------------------------------------

  @ApiOperation({
    summary: 'Invalidate the current session',
    description:
      'Sets `refresh_token_hash` to NULL in the database, preventing any further token rotation. The access token remains valid until its TTL expires; the client must discard it locally.',
  })
  @ApiBearerAuth('access-token')
  @ApiResponse({
    status: 204,
    description: 'Session invalidated. No response body.',
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized — access token is missing or invalid.',
    type: ApiErrorResponseDto,
  })
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  logout(@CurrentUser() user: JwtPayload): Promise<void> {
    return this.authService.logout(user.sub);
  }

  // ---------------------------------------------------------------------------
  // POST /auth/refresh
  // ---------------------------------------------------------------------------

  @ApiOperation({
    summary: 'Rotate the token pair',
    description:
      'Validates the refresh token against the stored bcrypt hash and issues a new access + refresh pair. The old refresh token is invalidated after rotation. A hash mismatch (possible reuse after token theft) invalidates the entire session.',
  })
  @ApiBearerAuth('refresh-token')
  @ApiResponse({
    status: 200,
    description: 'Token pair rotated. Returns new access and refresh tokens.',
    type: AuthResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized — refresh token is malformed or expired.',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 403,
    description:
      'Forbidden — refresh token hash does not match (possible reuse after rotation). Session has been fully invalidated.',
    type: ApiErrorResponseDto,
  })
  @Public()
  @UseGuards(JwtRefreshGuard)
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(
    @Request()
    req: ExpressRequest & { user: JwtPayload & { refreshToken: string } },
  ): Promise<AuthResponseDto> {
    return this.authService.refreshTokens(req.user.sub, req.user.refreshToken);
  }

  // ---------------------------------------------------------------------------
  // GET /auth/me
  // ---------------------------------------------------------------------------

  @ApiOperation({
    summary: 'Get the current authenticated user profile',
    description:
      'Returns the profile of the user identified by the access token. No tokens are re-issued. Sensitive fields (passwordHash, refreshTokenHash) are never included in the response.',
  })
  @ApiBearerAuth('access-token')
  @ApiResponse({
    status: 200,
    description: 'Returns the authenticated user profile without tokens.',
    type: MeResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized — access token is missing or invalid.',
    type: ApiErrorResponseDto,
  })
  @Get('me')
  @HttpCode(HttpStatus.OK)
  getMe(@CurrentUser() user: JwtPayload): Promise<MeResponseDto> {
    return this.authService.getMe(user.sub);
  }
}