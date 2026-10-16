import { BadGatewayException, BadRequestException, Inject, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { CANDIDATE_PROVIDER, CandidateProvider } from './matchmaking/candidate-provider';
import { isCandidateData } from './matchmaking/candidate-data';
import { FastApiClient } from './matchmaking/fastapi.client';
import { FindPlayerDto } from './matchmaking/dto/find-player.dto';
import { MatchmakingResponseDto } from './matchmaking/dto/matchmaking-response.dto';

@Injectable()
export class MatchmakingService {
  constructor(
    @Inject(CANDIDATE_PROVIDER) private readonly candidates: CandidateProvider,
    private readonly fastApi: FastApiClient,
  ) {}

  async getRecommendedMatches(userId: number, criteria: FindPlayerDto): Promise<MatchmakingResponseDto> {
    if (criteria.minSkillLevel !== undefined && criteria.maxSkillLevel !== undefined &&
        criteria.minSkillLevel > criteria.maxSkillLevel) {
      throw new BadRequestException('minSkillLevel không được lớn hơn maxSkillLevel');
    }
    let data: unknown;
    try {
      data = await this.candidates.getCandidates(userId, criteria);
    } catch {
      throw new ServiceUnavailableException('Dịch vụ dữ liệu ứng viên chưa sẵn sàng');
    }
    if (!isCandidateData(data, userId)) throw new BadGatewayException('Dữ liệu ứng viên không hợp lệ');
    if (data.candidates.length === 0) return { matchedUsers: [], totalCandidatesProcessed: 0 };
    return this.fastApi.recommend(data);
  }
}
