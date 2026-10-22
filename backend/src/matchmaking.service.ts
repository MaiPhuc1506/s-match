import { BadGatewayException, BadRequestException, Inject, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { CANDIDATE_PROVIDER, CandidateProvider } from './matchmaking/candidate-provider';
import { isCandidateData } from './matchmaking/candidate-data';
import { FastApiClient } from './matchmaking/fastapi.client';
import { FindPlayerDto } from './matchmaking/dto/find-player.dto';
import { MatchmakingResponseDto } from './matchmaking/dto/matchmaking-response.dto';
import { RoleName } from '@prisma/client';
import { PrismaService } from './prisma/prisma.service';
import { RecommendationHistoryService } from './recommendation-history/recommendation-history.service';

@Injectable()
export class MatchmakingService {
  constructor(
    @Inject(CANDIDATE_PROVIDER) private readonly candidates: CandidateProvider,
    private readonly fastApi: FastApiClient,
    private readonly prisma: PrismaService,
    private readonly history: RecommendationHistoryService,
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
    if (data.candidates.length === 0) return this.saveSearch(userId, criteria, { matchedUsers: [], totalCandidatesProcessed: 0 });
    const ranked = await this.fastApi.recommend(data);
    if (ranked.matchedUsers.length === 0) return this.saveSearch(userId, criteria, { matchedUsers: [], totalCandidatesProcessed: ranked.totalCandidatesProcessed });

    // FastAPI identities refer to User.id, not PlayerProfile.id.
    const userIds = ranked.matchedUsers.map(({ userId }) => {
      if (!/^[1-9]\d*$/.test(userId) || !Number.isInteger(Number(userId)) || Number(userId) > 2147483647) {
        throw new BadGatewayException('Phản hồi dịch vụ matchmaking không hợp lệ');
      }
      return Number(userId);
    });
    const profiles = await this.prisma.playerProfile.findMany({
      where: { userId: { in: userIds }, user: { role: { name: RoleName.PLAYER } } },
      select: {
        userId: true, nickname: true, avatarUrl: true, skillLevel: true,
        user: { select: { fullName: true } },
      },
    }).catch(() => {
      throw new ServiceUnavailableException('Dịch vụ hồ sơ người chơi chưa sẵn sàng');
    });
    const byUserId = new Map(profiles.map((profile) => [String(profile.userId), profile]));
    return this.saveSearch(userId, criteria, {
      // Iterate ranking, never the database rows: IN queries do not preserve order.
      matchedUsers: ranked.matchedUsers.flatMap(({ userId, matchScore }) => {
        const profile = byUserId.get(userId);
        if (!profile) return [];
        return [{
          userId, matchScore,
          profile: {
            fullName: profile.user.fullName ?? null,
            nickname: profile.nickname ?? null,
            avatarUrl: profile.avatarUrl ?? null,
            skillLevel: profile.skillLevel ?? null,
          },
        }];
      }),
      totalCandidatesProcessed: ranked.totalCandidatesProcessed,
    });
  }

  private async saveSearch(userId: number, criteria: FindPlayerDto, result: MatchmakingResponseDto) {
    try {
      await this.history.recordSession(userId, {
        criteria: { ...criteria },
        totalCandidatesProcessed: result.totalCandidatesProcessed,
        results: result.matchedUsers.map(({ userId, matchScore }) => ({
          recommendedUserId: Number(userId), matchScore,
        })),
      });
    } catch {
      throw new ServiceUnavailableException('Không thể lưu lịch sử gợi ý. Vui lòng thử lại.');
    }
    return result;
  }
}
