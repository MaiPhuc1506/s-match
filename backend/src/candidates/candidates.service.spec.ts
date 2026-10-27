import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { CandidatesService } from './candidates.service';
import { PrismaService } from '../prisma/prisma.service';
import { AvailabilityService } from '../availability-preference/availability.service';
import { RatingsService } from '../ratings/ratings.service';

describe('CandidatesService', () => {
  let service: CandidatesService;
  let prisma: any;
  let availabilityService: { getUpcomingTimeSlots: jest.Mock };
  let ratingsService: { getReliabilityScores: jest.Mock };

  const baseProfile = (userId: number, lat: number, lon: number, skill: any = null) => ({
    userId,
    nickname: `p${userId}`,
    skillLevel: 'INTERMEDIATE',
    latitude: lat,
    longitude: lon,
    user: { id: userId, fullName: `Player ${userId}` },
    skill,
  });

  const strongSkill = {
    smash: 4.5,
    defense: 3,
    netPlay: 4,
    stamina: 3,
    footwork: 3,
    serve: 4,
  };

  beforeEach(async () => {
    prisma = {
      playerProfile: { upsert: jest.fn(), findUnique: jest.fn(), findMany: jest.fn() },
      playingPreference: { findUnique: jest.fn(), findMany: jest.fn() },
    };
    availabilityService = { getUpcomingTimeSlots: jest.fn() };
    ratingsService = {
      getReliabilityScores: jest.fn(async (ids: number[]) => new Map(ids.map((id) => [id, 5]))),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CandidatesService,
        { provide: PrismaService, useValue: prisma },
        { provide: AvailabilityService, useValue: availabilityService },
        { provide: RatingsService, useValue: ratingsService },
      ],
    }).compile();

    service = module.get(CandidatesService);
  });

  describe('updateMyLocation', () => {
    it('upserts the player profile with the new coordinates', async () => {
      prisma.playerProfile.upsert.mockResolvedValue({
        latitude: 16.05,
        longitude: 108.2,
        locationUpdatedAt: new Date(),
      });

      const result = await service.updateMyLocation(1, { latitude: 16.05, longitude: 108.2 });

      expect(prisma.playerProfile.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { userId: 1 },
          create: expect.objectContaining({ userId: 1, latitude: 16.05, longitude: 108.2 }),
        }),
      );
      expect(result.latitude).toBe(16.05);
    });
  });

  describe('findNearby', () => {
    it('throws BadRequestException when the user has no location yet', async () => {
      prisma.playerProfile.findUnique.mockResolvedValue({ userId: 1, latitude: null, longitude: null });
      await expect(service.findNearby(1, {})).rejects.toThrow(BadRequestException);
    });

    it('filters by exact radius and sorts nearest first', async () => {
      prisma.playerProfile.findUnique.mockResolvedValue(baseProfile(1, 16.0, 108.0));
      prisma.playingPreference.findUnique.mockResolvedValue(null);
      prisma.playerProfile.findMany.mockResolvedValue([
        baseProfile(2, 16.05, 108.0), // ~5.5 km
        baseProfile(3, 16.02, 108.0), // ~2.2 km
        baseProfile(4, 16.09, 108.0), // ~10 km → ngoài bán kính 8km
      ]);

      const result = await service.findNearby(1, { radiusKm: 8 });

      expect(result.candidates.map((c) => c.userId)).toEqual([3, 2]);
      expect(result.candidates[0].distanceKm).toBeLessThan(result.candidates[1].distanceKm);
    });

    it('respects the limit', async () => {
      prisma.playerProfile.findUnique.mockResolvedValue(baseProfile(1, 16.0, 108.0));
      prisma.playingPreference.findUnique.mockResolvedValue(null);
      prisma.playerProfile.findMany.mockResolvedValue([
        baseProfile(2, 16.01, 108.0),
        baseProfile(3, 16.02, 108.0),
        baseProfile(4, 16.03, 108.0),
      ]);

      const result = await service.findNearby(1, { radiusKm: 10, limit: 2 });
      expect(result.candidates).toHaveLength(2);
    });
  });

  describe('buildMatchmakingRequest', () => {
    it('builds a payload matching the Matchmaking Service schema and drops candidates without slots', async () => {
      prisma.playerProfile.findUnique.mockResolvedValue(baseProfile(1, 16.0, 108.0, strongSkill));
      prisma.playingPreference.findUnique.mockResolvedValue({
        minSkillLevel: 2,
        maxSkillLevel: 4,
        maxDistanceKm: 12,
      });
      prisma.playerProfile.findMany.mockResolvedValue([
        baseProfile(2, 16.01, 108.0, strongSkill),
        baseProfile(3, 16.02, 108.0, strongSkill),
      ]);
      prisma.playingPreference.findMany.mockResolvedValue([
        { userId: 2, minSkillLevel: 1, maxSkillLevel: 5, maxDistanceKm: 8 },
      ]);
      availabilityService.getUpcomingTimeSlots.mockImplementation(async (userId: number) =>
        userId === 3 ? [] : ['2026-10-19T18:00:00.000Z'],
      );

      const { request, meta } = await service.buildMatchmakingRequest(1, { topK: 3 });

      expect(request.limit).toBe(3);
      expect(request.current_user.user_id).toBe('1');
      expect(request.current_user.skill.preferred_min).toBe(2);
      expect(request.current_user.skill.preferred_max).toBe(4);
      expect(request.current_user.skill.net_play).toBe(4);
      expect(request.current_user.max_distance_km).toBe(12);
      expect(request.current_user.playing_style).toEqual(['Attack']);
      expect(request.current_user.available_time_slots).toEqual(['2026-10-19T18:00:00.000Z']);

      expect(request.candidates.map((c) => c.user_id)).toEqual(['2']);
      expect(meta.candidatesInRadius).toBe(2);
      expect(meta.candidatesSent).toBe(1);
    });

    it('falls back to defaults when preference and skill are missing', async () => {
      prisma.playerProfile.findUnique.mockResolvedValue(baseProfile(1, 16.0, 108.0, null));
      prisma.playingPreference.findUnique.mockResolvedValue(null);
      prisma.playerProfile.findMany.mockResolvedValue([]);
      availabilityService.getUpcomingTimeSlots.mockResolvedValue([]);

      const { request } = await service.buildMatchmakingRequest(1, {});

      expect(request.current_user.skill.preferred_min).toBe(1);
      expect(request.current_user.skill.preferred_max).toBe(5);
      expect(request.current_user.max_distance_km).toBe(10);
      expect(request.current_user.playing_style).toEqual([]);
      expect(request.limit).toBe(5);
    });
  });
});
