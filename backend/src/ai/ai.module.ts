import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import axios from 'axios';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { FacilitiesModule } from '../facilities/facilities.module';
import { BookingsModule } from '../bookings/bookings.module';
import { MatchmakingModule } from '../matchmaking.module';
import { CandidatesModule } from '../candidates/candidates.module';
import { AvailabilityPreferenceModule } from '../availability-preference/availability-preference.module';
import { AnalyticsModule } from '../analytics/analytics.module';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { AiToolsService } from './ai-tools.service';
import { SwappableLlmProvider } from './providers/swappable-llm.provider';
import { AI_HTTP_CLIENT, LLM_PROVIDER } from './interfaces/llm-provider.interface';

@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    AuthModule,
    FacilitiesModule,
    BookingsModule,
    MatchmakingModule,
    CandidatesModule,
    AvailabilityPreferenceModule,
    AnalyticsModule,
  ],
  controllers: [AiController],
  providers: [
    AiService,
    AiToolsService,
    SwappableLlmProvider,
    {
      provide: AI_HTTP_CLIENT,
      useFactory: () => axios.create(),
    },
    {
      provide: LLM_PROVIDER,
      useExisting: SwappableLlmProvider,
    },
  ],
  exports: [AiService, AiToolsService],
})
export class AiModule {}
