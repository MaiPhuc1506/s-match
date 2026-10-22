import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, RecommendationOutcome } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ListHistoryQueryDto } from './dto/recommendation-history.dto';

const DEFAULT_PAGE = 1;
const DEFAULT_LIMIT = 20;


export interface RecordRecommendationInput {
  criteria?: Record<string, unknown>;
  totalCandidatesProcessed: number;
  results: Array<{
    recommendedUserId: number;
    matchScore: number;
    breakdown?: Record<string, number>;
  }>;
}

const ALLOWED_TRANSITIONS: Record<RecommendationOutcome, RecommendationOutcome[]> = {
  [RecommendationOutcome.SHOWN]: [RecommendationOutcome.INVITED, RecommendationOutcome.DISMISSED],
  [RecommendationOutcome.INVITED]: [RecommendationOutcome.ACCEPTED, RecommendationOutcome.DISMISSED],
  [RecommendationOutcome.ACCEPTED]: [],
  [RecommendationOutcome.DISMISSED]: [],
};

const sessionInclude = {
  results: {
    orderBy: { rank: 'asc' as const },
    include: { recommendedUser: { select: { id: true, fullName: true } } },
  },
};

const round = (value: number, digits: number) => {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
};

@Injectable()
export class RecommendationHistoryService {
  constructor(private readonly prisma: PrismaService) {}

  async recordSession(userId: number, input: RecordRecommendationInput) {
    if (!Number.isInteger(input.totalCandidatesProcessed) || input.totalCandidatesProcessed < 0) {
      throw new BadRequestException('totalCandidatesProcessed phải là số nguyên không âm');
    }

    const ids = input.results.map((r) => r.recommendedUserId);
    if (new Set(ids).size !== ids.length) {
      throw new BadRequestException('Danh sách gợi ý có người chơi bị trùng');
    }
    if (ids.includes(userId)) {
      throw new BadRequestException('Không thể gợi ý chính người đang tìm kiếm');
    }
    if (input.results.some((r) => !Number.isFinite(r.matchScore))) {
      throw new BadRequestException('matchScore phải là số hợp lệ');
    }

    if (ids.length > 0) {
      const existing = await this.prisma.user.findMany({
        where: { id: { in: ids } },
        select: { id: true },
      });
      if (existing.length !== ids.length) {
        throw new BadRequestException('Có người chơi được gợi ý không tồn tại');
      }
    }

    return this.prisma.recommendationSession.create({
      data: {
        userId,
        criteria: input.criteria as Prisma.InputJsonValue | undefined,
        totalCandidatesProcessed: input.totalCandidatesProcessed,
        results: {
          create: input.results.map((r, index) => ({
            recommendedUserId: r.recommendedUserId,
            rank: index + 1,
            matchScore: r.matchScore,
            breakdown: r.breakdown as Prisma.InputJsonValue | undefined,
          })),
        },
      },
      include: sessionInclude,
    });
  }

  async listMine(userId: number, query: ListHistoryQueryDto) {
    const page = query.page ?? DEFAULT_PAGE;
    const limit = query.limit ?? DEFAULT_LIMIT;

    const [items, total] = await Promise.all([
      this.prisma.recommendationSession.findMany({
        where: { userId },
        include: sessionInclude,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.recommendationSession.count({ where: { userId } }),
    ]);

    return { items, page, limit, total, totalPages: Math.ceil(total / limit) };
  }

  async findOneOrThrow(userId: number, sessionId: number) {
    const session = await this.prisma.recommendationSession.findUnique({
      where: { id: sessionId },
      include: sessionInclude,
    });
    if (!session || session.userId !== userId) {
      throw new NotFoundException(`Không tìm thấy phiên gợi ý ID ${sessionId}`);
    }
    return session;
  }

  async updateOutcome(
    userId: number,
    sessionId: number,
    resultId: number,
    outcome: RecommendationOutcome,
  ) {
    const result = await this.prisma.recommendationResult.findFirst({
      where: { id: resultId, sessionId, session: { userId } },
    });
    if (!result) {
      throw new NotFoundException(`Không tìm thấy kết quả gợi ý ID ${resultId} trong phiên ${sessionId}`);
    }

    if (!ALLOWED_TRANSITIONS[result.outcome].includes(outcome)) {
      throw new BadRequestException(
        `Không thể chuyển trạng thái từ ${result.outcome} sang ${outcome}`,
      );
    }

    return this.prisma.recommendationResult.update({
      where: { id: resultId },
      data: { outcome, outcomeUpdatedAt: new Date() },
      include: { recommendedUser: { select: { id: true, fullName: true } } },
    });
  }

  async remove(userId: number, sessionId: number) {
    await this.findOneOrThrow(userId, sessionId);
    await this.prisma.recommendationSession.delete({ where: { id: sessionId } });
    return { deleted: true };
  }

  async getStats(userId: number) {
    const where = { session: { userId } };

    const [totalSessions, grouped, aggregate] = await Promise.all([
      this.prisma.recommendationSession.count({ where: { userId } }),
      this.prisma.recommendationResult.groupBy({
        by: ['outcome'],
        where,
        _count: { _all: true },
      }),
      this.prisma.recommendationResult.aggregate({
        where,
        _avg: { matchScore: true },
        _count: { _all: true },
      }),
    ]);

    const count = (outcome: RecommendationOutcome) =>
      grouped.find((g) => g.outcome === outcome)?._count._all ?? 0;

    const totalRecommended = aggregate._count._all;
    const shown = count(RecommendationOutcome.SHOWN);
    const invited = count(RecommendationOutcome.INVITED);
    const accepted = count(RecommendationOutcome.ACCEPTED);
    const dismissed = count(RecommendationOutcome.DISMISSED);
    const contacted = invited + accepted;

    return {
      totalSessions,
      totalRecommended,
      outcomes: { shown, invited, accepted, dismissed },
      invitationRate: totalRecommended > 0 ? round(contacted / totalRecommended, 4) : 0,
      acceptanceRate: contacted > 0 ? round(accepted / contacted, 4) : 0,
      averageMatchScore: round(aggregate._avg.matchScore ?? 0, 2),
    };
  }
}
