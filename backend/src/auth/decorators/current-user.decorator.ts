import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { Request } from 'express';

import { JwtPayload } from '../types/jwt-payload.type';

/**
 * Parameter decorator that extracts the JWT payload from `request.user`
 * as set by {@link JwtAuthGuard}.
 *
 * @example
 * ```TypeScript
 * @Get('me')
 * getMe(@CurrentUser() user: JwtPayload) {
 *   return this.authService.getMe(user.sub);
 * }
 * ```
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtPayload => {
    const request = ctx.switchToHttp().getRequest<Request>();
    return request.user as JwtPayload;
  },
);