import { Module } from '@nestjs/common';
import axios from 'axios';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { CANDIDATE_PROVIDER, UnavailableCandidateProvider } from './matchmaking/candidate-provider';
import { FASTAPI_HTTP, FastApiClient } from './matchmaking/fastapi.client';
import { MatchmakingService } from './matchmaking.service';
import { MatchmakingController } from './matchmaking.controller';

@Module({
  imports: [
    ConfigModule, AuthModule,
  ],
  controllers: [MatchmakingController],
  providers: [MatchmakingService, FastApiClient,
    { provide: FASTAPI_HTTP, useFactory: () => axios.create() },
    { provide: CANDIDATE_PROVIDER, useClass: UnavailableCandidateProvider }],
})
export class MatchmakingModule {}
