import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { MatchmakingService } from './matchmaking.service';
import { MatchmakingController } from './matchmaking.controller';

@Module({
  imports: [
    HttpModule.register({
      timeout: 5000,
      maxRedirects: 5,
    }),
  ],
  controllers: [MatchmakingController],
  providers: [MatchmakingService],
})
export class MatchmakingModule {}