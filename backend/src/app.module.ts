import { Module } from '@nestjs/common';
import { ConfigModule, ConfigType } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UserEntity } from './users/entities/user.entity';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { appConfig, databaseConfig, jwtConfig } from './config';

/**
 * Root application module.
 *
 * Responsibilities:
 * - Loads all typed configuration namespaces via `ConfigModule.forRoot`.
 * - Establishes the TypeORM PostgreSQL connection using the `database`
 *   namespace — no raw `process.env` access in module wiring.
 * - Imports feature modules: UsersModule, AuthModule.
 *
 * Configuration is validated at startup: missing required environment
 * variables cause an immediate exception before any port is opened
 * (fail-fast, OWASP A05).
 *
 * OWASP A03: TypeORM parameterises all queries; `synchronize: false` in
 * production prevents accidental schema destruction.
 */
@Module({
  imports: [
    // Load and validate all typed configuration namespaces globally.
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig, databaseConfig, jwtConfig],
    }),

    // PostgreSQL via TypeORM — delegates all values to the typed namespace.
    TypeOrmModule.forRootAsync({
      inject: [databaseConfig.KEY],
      useFactory: (db: ConfigType<typeof databaseConfig>) => ({
        type: 'postgres',
        host: db.host,
        port: db.port,
        username: db.username,
        password: db.password,
        database: db.name,
        entities: [UserEntity],
        synchronize: db.synchronize,
        logging: db.logging,
      }),
    }),

    UsersModule,
    AuthModule,
  ],
})
export class AppModule {}