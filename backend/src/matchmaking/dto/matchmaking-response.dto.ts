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

export class MatchBreakdownDto {
  @ApiProperty({ minimum: 0, maximum: 100 }) skill_score: number;
  @ApiProperty({ minimum: 0, maximum: 100 }) distance_score: number;
  @ApiProperty({ minimum: 0, maximum: 100 }) time_score: number;
  @ApiProperty({ minimum: 0, maximum: 100 }) reliability_score: number;
  @ApiProperty({ minimum: 0, maximum: 100 }) style_score: number;
}

export class MatchedPlayerDto {
  @ApiProperty()
  userId: string;

  @ApiProperty()
  matchScore: number;

  @ApiProperty({ type: MatchBreakdownDto })
  breakdown: MatchBreakdownDto;

  @ApiProperty({ type: RecommendationProfileDto })
  profile: RecommendationProfileDto;
}

export class MatchmakingResponseDto {
  @ApiProperty({ type: [MatchedPlayerDto] })
  matchedUsers: MatchedPlayerDto[];

  @ApiProperty({ minimum: 0 })
  totalCandidatesProcessed: number;
}
