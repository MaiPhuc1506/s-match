import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MatchState, ParticipantStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateRatingDto, ListRatingsQueryDto, UpdateRatingDto } from './dto/rating.dto';

const DEFAULT_PAGE = 1;
const DEFAULT_LIMIT = 20;
const MAX_PENDING_MATCHES = 50;

export const RATING_WINDOW_DAYS = 14;
export const RATING_EDIT_WINDOW_HOURS = 24;
export const DEFAULT_RELIABILITY_SCORE = 5.0;
export const RELIABILITY_PRIOR_WEIGHT = 3;

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

const userSelect = { select: { id: true, fullName: true } } as const;

const ratingInclude = {
  rater: userSelect,
  ratedUser: userSelect,
  match: { select: { id: true, title: true, startTime: true, endTime: true } },
} as const;

const round = (value: number, digits: number) => {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
};

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

export function computeReliabilityScore(count: number, average: number | null): number {
  if (!count || average === null || !Number.isFinite(average)) return DEFAULT_RELIABILITY_SCORE;
  const smoothed =
    (average * count + DEFAULT_RELIABILITY_SCORE * RELIABILITY_PRIOR_WEIGHT) /
    (count + RELIABILITY_PRIOR_WEIGHT);
  return round(clamp(smoothed, 0, 5), 2);
}

@Injectable()
export class RatingsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(raterId: number, dto: CreateRatingDto) {
    if (dto.ratedUserId === raterId) {
      throw new BadRequestException('Bạn không thể tự đánh giá chính mình');
    }

    const match = await this.prisma.match.findUnique({
      where: { id: dto.matchId },
      select: {
        id: true,
        status: true,
        endTime: true,
        participants: {
          where: {
            userId: { in: [raterId, dto.ratedUserId] },
            status: ParticipantStatus.ACCEPTED,
          },
          select: { userId: true },
        },
      },
    });
    if (!match) {
      throw new NotFoundException(`Không tìm thấy trận đấu ID ${dto.matchId}`);
    }

    const participantIds = new Set(match.participants.map((p) => p.userId));
    if (!participantIds.has(raterId)) {
      throw new ForbiddenException('Bạn không tham gia trận đấu này nên không thể đánh giá');
    }
    if (!participantIds.has(dto.ratedUserId)) {
      throw new BadRequestException('Người được đánh giá không tham gia trận đấu này');
    }

    if (match.status === MatchState.CANCELLED) {
      throw new BadRequestException('Trận đấu đã bị huỷ, không thể đánh giá');
    }
    const now = Date.now();
    const endedAt = match.endTime.getTime();
    if (endedAt > now) {
      throw new BadRequestException('Trận đấu chưa kết thúc, chưa thể đánh giá');
    }
    if (now - endedAt > RATING_WINDOW_DAYS * DAY_MS) {
      throw new BadRequestException(
        `Đã quá ${RATING_WINDOW_DAYS} ngày kể từ khi trận kết thúc, không thể đánh giá`,
      );
    }

    try {
      return await this.prisma.$transaction(async (tx) => {
        const created = await tx.playerRating.create({
          data: {
            matchId: dto.matchId,
            raterId,
            ratedUserId: dto.ratedUserId,
            score: dto.score,
            punctuality: dto.punctuality,
            sportsmanship: dto.sportsmanship,
            comment: dto.comment || null,
          },
          include: ratingInclude,
        });
        await this.recordHistory(tx, dto.ratedUserId, created.id);
        return created;
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Bạn đã đánh giá người chơi này trong trận này rồi');
      }
      throw error;
    }
  }

  async update(raterId: number, ratingId: number, dto: UpdateRatingDto) {
    const rating = await this.prisma.playerRating.findFirst({
      where: { id: ratingId, raterId },
    });
    if (!rating) {
      throw new NotFoundException(`Không tìm thấy đánh giá ID ${ratingId}`);
    }

    const data: Prisma.PlayerRatingUpdateInput = {};
    if (dto.score !== undefined) data.score = dto.score;
    if (dto.punctuality !== undefined) data.punctuality = dto.punctuality;
    if (dto.sportsmanship !== undefined) data.sportsmanship = dto.sportsmanship;
    if (dto.comment !== undefined) data.comment = dto.comment === '' ? null : dto.comment;

    if (Object.keys(data).length === 0) {
      throw new BadRequestException('Không có trường nào để cập nhật');
    }
    if (Date.now() - rating.createdAt.getTime() > RATING_EDIT_WINDOW_HOURS * HOUR_MS) {
      throw new BadRequestException(
        `Chỉ được sửa đánh giá trong vòng ${RATING_EDIT_WINDOW_HOURS} giờ sau khi tạo`,
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.playerRating.update({
        where: { id: ratingId },
        data,
        include: ratingInclude,
      });
      await this.recordHistory(tx, rating.ratedUserId, ratingId);
      return updated;
    });
  }

  async listHistory(userId: number, query: ListRatingsQueryDto) {
    await this.requireUser(userId);
    const page = query.page ?? DEFAULT_PAGE;
    const limit = query.limit ?? DEFAULT_LIMIT;
    const where = { userId };

    const [items, total] = await Promise.all([
      this.prisma.ratingHistory.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.ratingHistory.count({ where }),
    ]);

    return { items, page, limit, total, totalPages: Math.ceil(total / limit) };
  }

  private async recordHistory(db: Prisma.TransactionClient, userId: number, ratingId: number) {
    const aggregate = await db.playerRating.aggregate({
      where: { ratedUserId: userId },
      _avg: { score: true },
      _count: { _all: true },
    });
    const ratingCount = aggregate._count._all;
    const average = aggregate._avg.score ?? null;
    await db.ratingHistory.create({
      data: {
        userId,
        ratingId,
        ratingCount,
        communityRating: average === null ? 0 : round(average, 2),
        reliabilityScore: computeReliabilityScore(ratingCount, average),
      },
    });
  }

  async listGiven(raterId: number, query: ListRatingsQueryDto) {
    return this.paginate({ raterId }, query);
  }

  async listReceived(userId: number, query: ListRatingsQueryDto) {
    await this.requireUser(userId);
    return this.paginate({ ratedUserId: userId }, query);
  }

  async listPending(userId: number) {
    const now = new Date();
    const windowStart = new Date(now.getTime() - RATING_WINDOW_DAYS * DAY_MS);

    const matches = await this.prisma.match.findMany({
      where: {
        status: { not: MatchState.CANCELLED },
        endTime: { lte: now, gte: windowStart },
        participants: { some: { userId, status: ParticipantStatus.ACCEPTED } },
      },
      select: {
        id: true,
        title: true,
        startTime: true,
        endTime: true,
        participants: {
          where: { status: ParticipantStatus.ACCEPTED, userId: { not: userId } },
          select: { user: userSelect },
        },
        ratings: { where: { raterId: userId }, select: { ratedUserId: true } },
      },
      orderBy: { endTime: 'desc' },
      take: MAX_PENDING_MATCHES,
    });

    return matches
      .map((match) => {
        const rated = new Set(match.ratings.map((r) => r.ratedUserId));
        return {
          matchId: match.id,
          title: match.title,
          startTime: match.startTime,
          endTime: match.endTime,
          players: match.participants.map((p) => p.user).filter((u) => !rated.has(u.id)),
        };
      })
      .filter((match) => match.players.length > 0);
  }

  async getSummary(userId: number) {
    await this.requireUser(userId);
    const where = { ratedUserId: userId };

    const [aggregate, grouped] = await Promise.all([
      this.prisma.playerRating.aggregate({
        where,
        _avg: { score: true, punctuality: true, sportsmanship: true },
        _count: { _all: true },
      }),
      this.prisma.playerRating.groupBy({ by: ['score'], where, _count: { _all: true } }),
    ]);

    const distribution: Record<string, number> = { '1': 0, '2': 0, '3': 0, '4': 0, '5': 0 };
    for (const row of grouped) distribution[String(row.score)] = row._count._all;

    const ratingCount = aggregate._count._all;
    const avg = (value: number | null | undefined) => (value == null ? null : round(value, 2));

    return {
      userId,
      ratingCount,
      communityRating: avg(aggregate._avg.score),
      averageScore: avg(aggregate._avg.score),
      averagePunctuality: avg(aggregate._avg.punctuality),
      averageSportsmanship: avg(aggregate._avg.sportsmanship),
      distribution,
      reliabilityScore: computeReliabilityScore(ratingCount, aggregate._avg.score ?? null),
    };
  }

  async getReliabilityScores(userIds: number[]): Promise<Map<number, number>> {
    const scores = new Map<number, number>(userIds.map((id) => [id, DEFAULT_RELIABILITY_SCORE]));
    if (userIds.length === 0) return scores;

    const grouped = await this.prisma.playerRating.groupBy({
      by: ['ratedUserId'],
      where: { ratedUserId: { in: userIds } },
      _avg: { score: true },
      _count: { _all: true },
    });
    for (const row of grouped) {
      scores.set(row.ratedUserId, computeReliabilityScore(row._count._all, row._avg.score ?? null));
    }
    return scores;
  }

  private async requireUser(userId: number) {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { id: true } });
    if (!user) {
      throw new NotFoundException(`Không tìm thấy người dùng ID ${userId}`);
    }
  }

  private async paginate(where: Prisma.PlayerRatingWhereInput, query: ListRatingsQueryDto) {
    const page = query.page ?? DEFAULT_PAGE;
    const limit = query.limit ?? DEFAULT_LIMIT;

    const [items, total] = await Promise.all([
      this.prisma.playerRating.findMany({
        where,
        include: ratingInclude,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.playerRating.count({ where }),
    ]);

    return { items, page, limit, total, totalPages: Math.ceil(total / limit) };
  }
}
