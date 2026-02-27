import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';

import { UsersModule } from '../users/users.module';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { LocalStrategy } from './strategies/local.strategy';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtRefreshStrategy } from './strategies/jwt-refresh.strategy';
import { JwtAuthGuard } from './guards/auth.guards';
import { jwtConfig } from '../config';

/**
 * Authentication feature module.
 *
 * Registers all Passport strategies, the global JWT guard, and the auth
 * service / controller. Imports {@link UsersModule} for user persistence
 * operations.
 *
 * `ConfigModule.forFeature(jwtConfig)` makes the `jwt` typed namespace
 * available for `@Inject(jwtConfig.KEY)` in {@link AuthService},
 * {@link JwtStrategy}, and {@link JwtRefreshStrategy}. The `ConfigModule`
 * is already global (loaded in AppModule), but `forFeature` is required
 * to register the namespace token in the local DI container.
 *
 * `JwtModule.register({})` is intentionally empty — tokens are signed
 * with explicit `secret` and `expiresIn` options inside
 * {@link AuthService.issueSessionFor} to allow different secrets and
 * expiries for access and refresh tokens.
 *
 * The global `APP_GUARD` binding applies {@link JwtAuthGuard} to every
 * route in the application. Routes that must be publicly accessible are
 * decorated with `@Public()`.
 */
@Module({
  imports: [
    UsersModule,
    PassportModule,
    JwtModule.register({}),
    // Register the jwt namespace token in the AuthModule DI container.
    ConfigModule.forFeature(jwtConfig),
  ],
  providers: [
    AuthService,
    LocalStrategy,
    JwtStrategy,
    JwtRefreshStrategy,
    // Apply JwtAuthGuard globally — routes opt out via @Public().
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
  controllers: [AuthController],
})
export class AuthModule {}