import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UserEntity } from './entities/user.entity';
import { UsersService } from './users.service';

/**
 * Encapsulates the User aggregate persistence layer.
 *
 * Exports {@link UsersService} so that AuthModule can inject it without
 * coupling the authentication logic directly to the TypeORM repository.
 */
@Module({
  imports: [TypeOrmModule.forFeature([UserEntity])],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}