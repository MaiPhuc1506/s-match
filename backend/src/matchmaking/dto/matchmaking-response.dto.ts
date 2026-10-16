import { ApiProperty } from '@nestjs/swagger';

// Temporary camelCase Flutter contract; upstream remains unchanged (snake_case).
export class MatchedPlayerDto {
  @ApiProperty()
  userId: string;

  @ApiProperty()
  matchScore: number;
}

export class MatchmakingResponseDto {
  @ApiProperty({ type: [MatchedPlayerDto] })
  matchedUsers: MatchedPlayerDto[];

  @ApiProperty({ minimum: 0 })
  totalCandidatesProcessed: number;
}
