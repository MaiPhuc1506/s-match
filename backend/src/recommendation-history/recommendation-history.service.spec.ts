import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { RecommendationOutcome } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RecommendationHistoryService } from './recommendation-history.service';

describe('RecommendationHistoryService', () => {
  let service: RecommendationHistoryService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      user: { findMany: jest.fn() },
      recommendationSession: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        count: jest.fn(),
        delete: jest.fn(),
      },
      recommendationResult: {
        findFirst: jest.fn(),
        update: jest.fn(),
        groupBy: jest.fn(),
        aggregate: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [RecommendationHistoryService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get(RecommendationHistoryService);
  });

  describe('recordSession', () => {
    const input = {
      criteria: { maxDistanceKm: 10 },
      totalCandidatesProcessed: 3,
      results: [
        { recommendedUserId: 7, matchScore: 91.5 },
        { recommendedUserId: 9, matchScore: 80, breakdown: { skill_score: 0.8 } },
      ],
    };

    it('rejects a negative or non-integer totalCandidatesProcessed', async () => {
      await expect(
        service.recordSession(1, { ...input, totalCandidatesProcessed: -1 }),
      ).rejects.toThrow(BadRequestException);
      await expect(
        service.recordSession(1, { ...input, totalCandidatesProcessed: 1.5 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects duplicate recommended users', async () => {
      await expect(
        service.recordSession(1, {
          ...input,
          results: [
            { recommendedUserId: 7, matchScore: 90 },
            { recommendedUserId: 7, matchScore: 80 },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects recommending the searching user', async () => {
      await expect(
        service.recordSession(7, { ...input, results: [{ recommendedUserId: 7, matchScore: 90 }] }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a non-finite matchScore', async () => {
      await expect(
        service.recordSession(1, {
          ...input,
          results: [{ recommendedUserId: 7, matchScore: Number.NaN }],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects when a recommended user does not exist', async () => {
      prisma.user.findMany.mockResolvedValue([{ id: 7 }]);
      await expect(service.recordSession(1, input)).rejects.toThrow(BadRequestException);
    });

    it('assigns rank by the engine order and stores everything in one nested create', async () => {
      prisma.user.findMany.mockResolvedValue([{ id: 7 }, { id: 9 }]);
      prisma.recommendationSession.create.mockResolvedValue({ id: 1 });

      await service.recordSession(1, input);

      const arg = prisma.recommendationSession.create.mock.calls[0][0];
      expect(arg.data.userId).toBe(1);
      expect(arg.data.totalCandidatesProcessed).toBe(3);
      expect(arg.data.results.create).toEqual([
        expect.objectContaining({ recommendedUserId: 7, rank: 1, matchScore: 91.5 }),
        expect.objectContaining({ recommendedUserId: 9, rank: 2, matchScore: 80 }),
      ]);
    });

    it('records an empty-result session without querying users', async () => {
      prisma.recommendationSession.create.mockResolvedValue({ id: 2 });

      await service.recordSession(1, { totalCandidatesProcessed: 0, results: [] });

      expect(prisma.user.findMany).not.toHaveBeenCalled();
      expect(prisma.recommendationSession.create).toHaveBeenCalled();
    });
  });

  describe('listMine', () => {
    it('paginates with defaults and returns totals', async () => {
      prisma.recommendationSession.findMany.mockResolvedValue([{ id: 1 }]);
      prisma.recommendationSession.count.mockResolvedValue(45);

      const result = await service.listMine(1, {});

      expect(prisma.recommendationSession.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { userId: 1 }, skip: 0, take: 20 }),
      );
      expect(result).toMatchObject({ page: 1, limit: 20, total: 45, totalPages: 3 });
    });

    it('computes skip from page and limit', async () => {
      prisma.recommendationSession.findMany.mockResolvedValue([]);
      prisma.recommendationSession.count.mockResolvedValue(0);

      await service.listMine(1, { page: 3, limit: 10 });

      expect(prisma.recommendationSession.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ skip: 20, take: 10 }),
      );
    });
  });

  describe('findOneOrThrow', () => {
    it('throws NotFoundException when the session does not exist', async () => {
      prisma.recommendationSession.findUnique.mockResolvedValue(null);
      await expect(service.findOneOrThrow(1, 99)).rejects.toThrow(NotFoundException);
    });

    it('throws NotFoundException (not Forbidden) for someone else’s session', async () => {
      prisma.recommendationSession.findUnique.mockResolvedValue({ id: 5, userId: 2 });
      await expect(service.findOneOrThrow(1, 5)).rejects.toThrow(NotFoundException);
    });

    it('returns the session for its owner', async () => {
      prisma.recommendationSession.findUnique.mockResolvedValue({ id: 5, userId: 1 });
      await expect(service.findOneOrThrow(1, 5)).resolves.toMatchObject({ id: 5 });
    });
  });

  describe('updateOutcome', () => {
    it('throws NotFoundException when the result is not in the user’s session', async () => {
      prisma.recommendationResult.findFirst.mockResolvedValue(null);
      await expect(
        service.updateOutcome(1, 5, 10, RecommendationOutcome.INVITED),
      ).rejects.toThrow(NotFoundException);
    });

    it('scopes the lookup by session and owner', async () => {
      prisma.recommendationResult.findFirst.mockResolvedValue(null);
      await service.updateOutcome(1, 5, 10, RecommendationOutcome.INVITED).catch(() => undefined);
      expect(prisma.recommendationResult.findFirst).toHaveBeenCalledWith({
        where: { id: 10, sessionId: 5, session: { userId: 1 } },
      });
    });

    it('rejects an invalid transition (SHOWN -> ACCEPTED)', async () => {
      prisma.recommendationResult.findFirst.mockResolvedValue({ id: 10, outcome: 'SHOWN' });
      await expect(
        service.updateOutcome(1, 5, 10, RecommendationOutcome.ACCEPTED),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects changing a terminal state (ACCEPTED -> DISMISSED)', async () => {
      prisma.recommendationResult.findFirst.mockResolvedValue({ id: 10, outcome: 'ACCEPTED' });
      await expect(
        service.updateOutcome(1, 5, 10, RecommendationOutcome.DISMISSED),
      ).rejects.toThrow(BadRequestException);
    });

    it('allows SHOWN -> INVITED and stamps outcomeUpdatedAt', async () => {
      prisma.recommendationResult.findFirst.mockResolvedValue({ id: 10, outcome: 'SHOWN' });
      prisma.recommendationResult.update.mockResolvedValue({ id: 10, outcome: 'INVITED' });

      await service.updateOutcome(1, 5, 10, RecommendationOutcome.INVITED);

      const arg = prisma.recommendationResult.update.mock.calls[0][0];
      expect(arg.data.outcome).toBe('INVITED');
      expect(arg.data.outcomeUpdatedAt).toBeInstanceOf(Date);
    });
  });

  describe('remove', () => {
    it('deletes the owner’s session', async () => {
      prisma.recommendationSession.findUnique.mockResolvedValue({ id: 5, userId: 1 });
      prisma.recommendationSession.delete.mockResolvedValue({});

      await expect(service.remove(1, 5)).resolves.toEqual({ deleted: true });
      expect(prisma.recommendationSession.delete).toHaveBeenCalledWith({ where: { id: 5 } });
    });

    it('does not delete someone else’s session', async () => {
      prisma.recommendationSession.findUnique.mockResolvedValue({ id: 5, userId: 2 });
      await expect(service.remove(1, 5)).rejects.toThrow(NotFoundException);
      expect(prisma.recommendationSession.delete).not.toHaveBeenCalled();
    });
  });

  describe('getStats', () => {
    it('computes rates from outcome counts', async () => {
      prisma.recommendationSession.count.mockResolvedValue(4);
      prisma.recommendationResult.groupBy.mockResolvedValue([
        { outcome: 'SHOWN', _count: { _all: 6 } },
        { outcome: 'INVITED', _count: { _all: 2 } },
        { outcome: 'ACCEPTED', _count: { _all: 1 } },
        { outcome: 'DISMISSED', _count: { _all: 1 } },
      ]);
      prisma.recommendationResult.aggregate.mockResolvedValue({
        _avg: { matchScore: 77.456 },
        _count: { _all: 10 },
      });

      const stats = await service.getStats(1);

      expect(stats.totalSessions).toBe(4);
      expect(stats.totalRecommended).toBe(10);
      expect(stats.outcomes).toEqual({ shown: 6, invited: 2, accepted: 1, dismissed: 1 });
      expect(stats.invitationRate).toBe(0.3); // (2 + 1) / 10
      expect(stats.acceptanceRate).toBe(0.3333); // 1 / (2 + 1)
      expect(stats.averageMatchScore).toBe(77.46);
    });

    it('returns zeros (no division by zero) when there is no history', async () => {
      prisma.recommendationSession.count.mockResolvedValue(0);
      prisma.recommendationResult.groupBy.mockResolvedValue([]);
      prisma.recommendationResult.aggregate.mockResolvedValue({
        _avg: { matchScore: null },
        _count: { _all: 0 },
      });

      const stats = await service.getStats(1);

      expect(stats).toEqual({
        totalSessions: 0,
        totalRecommended: 0,
        outcomes: { shown: 0, invited: 0, accepted: 0, dismissed: 0 },
        invitationRate: 0,
        acceptanceRate: 0,
        averageMatchScore: 0,
      });
    });
  });
});
