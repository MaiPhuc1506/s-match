import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PlayersController } from './players.controller';
import { PlayersService } from './players.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule, JwtModule],
  controllers: [PlayersController],
  providers: [PlayersService],
})
export class PlayersModule {}