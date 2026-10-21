import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { RecommendationHistoryController } from './recommendation-history.controller';
import { RecommendationHistoryService } from './recommendation-history.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [RecommendationHistoryController],
  providers: [RecommendationHistoryService],
  exports: [RecommendationHistoryService],
})
export class RecommendationHistoryModule {}
