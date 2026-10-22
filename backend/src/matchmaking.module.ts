import { RecommendationHistoryModule } from './recommendation-history/recommendation-history.module';
import { Module } from '@nestjs/common';
import axios from 'axios';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { CANDIDATE_PROVIDER } from './matchmaking/candidate-provider';
import { CandidatesModule } from './candidates/candidates.module';
import { DatabaseCandidateProvider } from './matchmaking/database-candidate-provider';
import { FASTAPI_HTTP, FastApiClient } from './matchmaking/fastapi.client';
import { MatchmakingService } from './matchmaking.service';
import { MatchmakingController } from './matchmaking.controller';

@Module({
  imports: [
    ConfigModule, AuthModule, CandidatesModule, RecommendationHistoryModule,
  ],
  controllers: [MatchmakingController],
  providers: [MatchmakingService, FastApiClient,
    { provide: FASTAPI_HTTP, useFactory: () => axios.create() },
    { provide: CANDIDATE_PROVIDER, useClass: DatabaseCandidateProvider }],
})
export class MatchmakingModule {}
