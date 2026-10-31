import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { MatchState, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  computeReliabilityScore,
  DEFAULT_RELIABILITY_SCORE,
  RATING_EDIT_WINDOW_HOURS,
  RATING_WINDOW_DAYS,
  RatingsService,
} from './ratings.service';

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

describe('RatingsService', () => {
  let service: RatingsService;
  let prisma: any;

  const endedMatch = (overrides: Record<string, unknown> = {}) => ({
    id: 10,
    status: MatchState.COMPLETED,
    endTime: new Date(Date.now() - 2 * HOUR),
    participants: [{ userId: 1 }, { userId: 2 }],
    ...overrides,
  });

  beforeEach(async () => {
    prisma = {
      user: { findUnique: jest.fn() },
      ratingHistory: { create: jest.fn(), findMany: jest.fn(), count: jest.fn() },
      $transaction: jest.fn((cb: (tx: unknown) => unknown) => cb(prisma)),
      match: { findUnique: jest.fn(), findMany: jest.fn() },
      playerRating: {
        create: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
        count: jest.fn(),
        aggregate: jest.fn(),
        groupBy: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [RatingsService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get(RatingsService);
    prisma.playerRating.aggregate.mockResolvedValue({ _avg: { score: 4.5 }, _count: { _all: 2 } });
  });

  describe('computeReliabilityScore', () => {
    it('returns the default for players without ratings', () => {
      expect(computeReliabilityScore(0, null)).toBe(DEFAULT_RELIABILITY_SCORE);
    });

    it('smooths a single low rating towards the default', () => {
      expect(computeReliabilityScore(1, 1)).toBe(4);
    });

    it('converges to the real average as ratings accumulate', () => {
      expect(computeReliabilityScore(27, 2)).toBe(2.3);
    });

    it('stays within 0..5', () => {
      expect(computeReliabilityScore(10, 5)).toBe(5);
      expect(computeReliabilityScore(10, 0)).toBeGreaterThanOrEqual(0);
    });
  });

  describe('create', () => {
    const dto = { matchId: 10, ratedUserId: 2, score: 5, comment: 'Chơi tốt' };

    it('creates a rating between two accepted participants of an ended match', async () => {
      prisma.match.findUnique.mockResolvedValue(endedMatch());
      prisma.playerRating.create.mockResolvedValue({ id: 1, ...dto, raterId: 1 });

      const result = await service.create(1, dto);

      expect(prisma.match.findUnique).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 10 },
          select: expect.objectContaining({
            participants: expect.objectContaining({
              where: { userId: { in: [1, 2] }, status: 'ACCEPTED' },
            }),
          }),
        }),
      );
      expect(prisma.playerRating.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            matchId: 10,
            raterId: 1,
            ratedUserId: 2,
            score: 5,
            comment: 'Chơi tốt',
          }),
        }),
      );
      expect(result.id).toBe(1);
    });

    it('records a Community Rating snapshot for the rated user in the same transaction', async () => {
      prisma.match.findUnique.mockResolvedValue(endedMatch());
      prisma.playerRating.create.mockResolvedValue({ id: 7 });

      await service.create(1, dto);

      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
      expect(prisma.playerRating.aggregate).toHaveBeenCalledWith(
        expect.objectContaining({ where: { ratedUserId: 2 } }),
      );
      expect(prisma.ratingHistory.create).toHaveBeenCalledWith({
        data: { userId: 2, ratingId: 7, ratingCount: 2, communityRating: 4.5, reliabilityScore: 4.8 },
      });
    });

    it('stores a missing or empty comment as null', async () => {
      prisma.match.findUnique.mockResolvedValue(endedMatch());
      prisma.playerRating.create.mockResolvedValue({ id: 1 });

      await service.create(1, { matchId: 10, ratedUserId: 2, score: 4, comment: '' });

      expect(prisma.playerRating.create.mock.calls[0][0].data.comment).toBeNull();
    });

    it('rejects rating yourself without touching the database', async () => {
      await expect(service.create(1, { ...dto, ratedUserId: 1 })).rejects.toThrow(BadRequestException);
      expect(prisma.match.findUnique).not.toHaveBeenCalled();
    });

    it('returns 404 when the match does not exist', async () => {
      prisma.match.findUnique.mockResolvedValue(null);
      await expect(service.create(1, dto)).rejects.toThrow(NotFoundException);
    });

    it('returns 403 when the rater is not an accepted participant', async () => {
      prisma.match.findUnique.mockResolvedValue(endedMatch({ participants: [{ userId: 2 }] }));
      await expect(service.create(1, dto)).rejects.toThrow(ForbiddenException);
      expect(prisma.playerRating.create).not.toHaveBeenCalled();
    });

    it('rejects a rated user who is not an accepted participant', async () => {
      prisma.match.findUnique.mockResolvedValue(endedMatch({ participants: [{ userId: 1 }] }));
      await expect(service.create(1, dto)).rejects.toThrow(BadRequestException);
    });

    it('rejects cancelled matches', async () => {
      prisma.match.findUnique.mockResolvedValue(endedMatch({ status: MatchState.CANCELLED }));
      await expect(service.create(1, dto)).rejects.toThrow(/huỷ/);
    });

    it.each([MatchState.OPEN, MatchState.FULL, MatchState.IN_PROGRESS])('rejects ended but uncompleted matches (%s)', async (status) => {
      prisma.match.findUnique.mockResolvedValue(endedMatch({ status }));
      await expect(service.create(1, dto)).rejects.toThrow(/hoàn thành/);
      expect(prisma.playerRating.create).not.toHaveBeenCalled();
    });

    it('rejects matches that have not ended yet', async () => {
      prisma.match.findUnique.mockResolvedValue(
        endedMatch({ endTime: new Date(Date.now() + HOUR) }),
      );
      await expect(service.create(1, dto)).rejects.toThrow(/chưa kết thúc/);
      expect(prisma.playerRating.create).not.toHaveBeenCalled();
    });

    it('rejects ratings after the rating window has closed', async () => {
      prisma.match.findUnique.mockResolvedValue(
        endedMatch({ endTime: new Date(Date.now() - (RATING_WINDOW_DAYS + 1) * DAY) }),
      );
      await expect(service.create(1, dto)).rejects.toThrow(BadRequestException);
      expect(prisma.playerRating.create).not.toHaveBeenCalled();
    });

    it('maps a unique-constraint violation to 409', async () => {
      prisma.match.findUnique.mockResolvedValue(endedMatch());
      prisma.playerRating.create.mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError('dup', { code: 'P2002', clientVersion: 'test' }),
      );
      await expect(service.create(1, dto)).rejects.toThrow(ConflictException);
    });

    it('rethrows unexpected database errors unchanged', async () => {
      prisma.match.findUnique.mockResolvedValue(endedMatch());
      const boom = new Error('db down');
      prisma.playerRating.create.mockRejectedValue(boom);
      await expect(service.create(1, dto)).rejects.toBe(boom);
    });
  });

  describe('update', () => {
    const existing = (createdAgoMs: number) => ({
      id: 5,
      raterId: 1,
      createdAt: new Date(Date.now() - createdAgoMs),
    });

    it('only looks up ratings owned by the caller', async () => {
      prisma.playerRating.findFirst.mockResolvedValue(null);
      await expect(service.update(1, 5, { score: 3 })).rejects.toThrow(NotFoundException);
      expect(prisma.playerRating.findFirst).toHaveBeenCalledWith({ where: { id: 5, raterId: 1 } });
    });

    it('updates the provided fields within the edit window', async () => {
      prisma.playerRating.findFirst.mockResolvedValue(existing(HOUR));
      prisma.playerRating.update.mockResolvedValue({ id: 5, score: 3 });

      await service.update(1, 5, { score: 3, comment: 'Ổn' });

      expect(prisma.playerRating.update).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: 5 }, data: { score: 3, comment: 'Ổn' } }),
      );
    });

    it('clears the comment when an empty string is sent', async () => {
      prisma.playerRating.findFirst.mockResolvedValue(existing(HOUR));
      prisma.playerRating.update.mockResolvedValue({ id: 5 });

      await service.update(1, 5, { comment: '' });

      expect(prisma.playerRating.update.mock.calls[0][0].data).toEqual({ comment: null });
    });

    it('records a history snapshot for the rated user after an edit', async () => {
      prisma.playerRating.findFirst.mockResolvedValue({ ...existing(HOUR), ratedUserId: 2 });
      prisma.playerRating.update.mockResolvedValue({ id: 5 });

      await service.update(1, 5, { score: 2 });

      expect(prisma.ratingHistory.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ userId: 2, ratingId: 5 }),
      });
    });

    it('rejects an empty update', async () => {
      prisma.playerRating.findFirst.mockResolvedValue(existing(HOUR));
      await expect(service.update(1, 5, {})).rejects.toThrow(BadRequestException);
    });

    it('rejects edits after the edit window', async () => {
      prisma.playerRating.findFirst.mockResolvedValue(
        existing((RATING_EDIT_WINDOW_HOURS + 1) * HOUR),
      );
      await expect(service.update(1, 5, { score: 2 })).rejects.toThrow(BadRequestException);
      expect(prisma.playerRating.update).not.toHaveBeenCalled();
    });
  });

  describe('listings', () => {
    beforeEach(() => {
      prisma.playerRating.findMany.mockResolvedValue([{ id: 1 }]);
      prisma.playerRating.count.mockResolvedValue(41);
    });

    it('paginates ratings I gave with defaults', async () => {
      const result = await service.listGiven(1, {});

      expect(prisma.playerRating.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { raterId: 1 }, skip: 0, take: 20 }),
      );
      expect(result).toEqual({ items: [{ id: 1 }], page: 1, limit: 20, total: 41, totalPages: 3 });
    });

    it('paginates received ratings and checks the user exists', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 2 });

      const result = await service.listReceived(2, { page: 3, limit: 10 });

      expect(prisma.playerRating.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { ratedUserId: 2 }, skip: 20, take: 10 }),
      );
      expect(result.totalPages).toBe(5);
    });

    it('returns 404 for received ratings of an unknown user', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(service.listReceived(99, {})).rejects.toThrow(NotFoundException);
    });
  });

  describe('listHistory', () => {
    it('paginates snapshots newest first', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 2 });
      prisma.ratingHistory.findMany.mockResolvedValue([{ id: 1 }]);
      prisma.ratingHistory.count.mockResolvedValue(3);

      const result = await service.listHistory(2, { page: 2, limit: 2 });

      expect(prisma.ratingHistory.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { userId: 2 }, skip: 2, take: 2 }),
      );
      expect(result).toEqual({ items: [{ id: 1 }], page: 2, limit: 2, total: 3, totalPages: 2 });
    });

    it('returns 404 for an unknown user', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(service.listHistory(99, {})).rejects.toThrow(NotFoundException);
    });
  });

  describe('listPending', () => {
    it('returns only unrated players and drops fully-rated matches', async () => {
      prisma.match.findMany.mockResolvedValue([
        {
          id: 10,
          title: 'Kèo tối',
          startTime: new Date(),
          endTime: new Date(),
          participants: [
            { user: { id: 2, fullName: 'B' } },
            { user: { id: 3, fullName: 'C' } },
          ],
          ratings: [{ ratedUserId: 2 }],
        },
        {
          id: 11,
          title: 'Kèo sáng',
          startTime: new Date(),
          endTime: new Date(),
          participants: [{ user: { id: 2, fullName: 'B' } }],
          ratings: [{ ratedUserId: 2 }],
        },
      ]);

      const result = await service.listPending(1);

      expect(result).toHaveLength(1);
      expect(result[0]).toMatchObject({ matchId: 10, players: [{ id: 3, fullName: 'C' }] });
      const where = prisma.match.findMany.mock.calls[0][0].where;
      expect(where.status).toEqual({ not: MatchState.CANCELLED });
      expect(where.participants).toEqual({ some: { userId: 1, status: 'ACCEPTED' } });
    });
  });

  describe('getSummary', () => {
    it('aggregates averages, distribution and reliability', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 2 });
      prisma.playerRating.aggregate.mockResolvedValue({
        _avg: { score: 4.333, punctuality: 5, sportsmanship: null },
        _count: { _all: 3 },
      });
      prisma.playerRating.groupBy.mockResolvedValue([
        { score: 5, _count: { _all: 2 } },
        { score: 3, _count: { _all: 1 } },
      ]);

      const result = await service.getSummary(2);

      expect(result).toEqual({
        userId: 2,
        ratingCount: 3,
        communityRating: 4.33,
        averageScore: 4.33,
        averagePunctuality: 5,
        averageSportsmanship: null,
        distribution: { '1': 0, '2': 0, '3': 1, '4': 0, '5': 2 },
        reliabilityScore: 4.67,
      });
    });

    it('reports null averages and the default reliability when there are no ratings', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 2 });
      prisma.playerRating.aggregate.mockResolvedValue({
        _avg: { score: null, punctuality: null, sportsmanship: null },
        _count: { _all: 0 },
      });
      prisma.playerRating.groupBy.mockResolvedValue([]);

      const result = await service.getSummary(2);

      expect(result).toMatchObject({
        ratingCount: 0,
        averageScore: null,
        reliabilityScore: DEFAULT_RELIABILITY_SCORE,
      });
    });

    it('returns 404 for an unknown user', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(service.getSummary(99)).rejects.toThrow(NotFoundException);
    });
  });

  describe('getReliabilityScores', () => {
    it('returns an empty map without querying when no ids are given', async () => {
      const result = await service.getReliabilityScores([]);
      expect(result.size).toBe(0);
      expect(prisma.playerRating.groupBy).not.toHaveBeenCalled();
    });

    it('covers every id: rated players get a smoothed score, others the default', async () => {
      prisma.playerRating.groupBy.mockResolvedValue([
        { ratedUserId: 2, _avg: { score: 1 }, _count: { _all: 1 } },
      ]);

      const result = await service.getReliabilityScores([1, 2, 3]);

      expect(prisma.playerRating.groupBy).toHaveBeenCalledTimes(1);
      expect(result.get(1)).toBe(DEFAULT_RELIABILITY_SCORE);
      expect(result.get(2)).toBe(4);
      expect(result.get(3)).toBe(DEFAULT_RELIABILITY_SCORE);
    });
  });
});
