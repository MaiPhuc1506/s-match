import { ApiProperty } from '@nestjs/swagger';

export class RecommendationProfileDto {
  @ApiProperty({ type: String, nullable: true })
  fullName: string | null;

  @ApiProperty({ type: String, nullable: true })
  nickname: string | null;

  @ApiProperty({ type: String, nullable: true })
  avatarUrl: string | null;

  @ApiProperty({ type: String, nullable: true })
  skillLevel: string | null;
}

export class MatchedPlayerDto {
  @ApiProperty()
  userId: string;

  @ApiProperty()
  matchScore: number;

  @ApiProperty({ type: RecommendationProfileDto })
  profile: RecommendationProfileDto;
}

export class MatchmakingResponseDto {
  @ApiProperty({ type: [MatchedPlayerDto] })
  matchedUsers: MatchedPlayerDto[];

  @ApiProperty({ minimum: 0 })
  totalCandidatesProcessed: number;
}
