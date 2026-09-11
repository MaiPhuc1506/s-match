import { Controller, Post, Body } from '@nestjs/common';
import { MatchmakingService } from './matchmaking.service';

@Controller('matchmaking')
export class MatchmakingController {
  constructor(private readonly matchmakingService: MatchmakingService) {}

  @Post('recommend')
  async getRecommendations(@Body() matchPayload: Record<string, any>) {
    return await this.matchmakingService.getRecommendedMatches(matchPayload);
  }
}