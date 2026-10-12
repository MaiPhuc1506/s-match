import { Module } from '@nestjs/common';
import { MatchesService } from './matches.service';
import { MatchesController, OpenMatchesController } from './matches.controller';
import { PrismaService } from '../prisma/prisma.service';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [MatchesController, OpenMatchesController],
  providers: [MatchesService, PrismaService],
  exports: [MatchesService],
})
export class MatchesModule {}
