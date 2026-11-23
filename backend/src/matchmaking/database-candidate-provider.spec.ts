import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { AppModule } from '../app.module';
import { AUTH_JWT_CONFIG } from '../auth/jwt.config';
import { AvailabilityService } from '../availability-preference/availability.service';
import { CandidatesService } from '../candidates/candidates.service';
import { RatingsService } from '../ratings/ratings.service';
import { PrismaService } from '../prisma/prisma.service';
import { RecommendationHistoryService } from '../recommendation-history/recommendation-history.service';
import { MatchmakingService } from '../matchmaking.service';
import { CANDIDATE_PROVIDER } from './candidate-provider';
import { DatabaseCandidateProvider } from './database-candidate-provider';
import { FASTAPI_HTTP, FastApiClient } from './fastapi.client';
import { FindPlayerDto } from './dto/find-player.dto';

describe('SMM-26 gateway with SMM-28 candidate data', () => {
  const skill = { smash: 4, defense: 3, netPlay: 4, stamina: 3, footwork: 3, serve: 4 };
  const profile = (userId: number, latitude: number | null, longitude: number | null) => ({
    userId, latitude, longitude, nickname: null, skillLevel: null,
    user: { id: userId, fullName: 'Fixture player' }, skill,
  });
  const criteria: FindPlayerDto = {
    location: { latitude: 16, longitude: 108 },
    availableTimeSlots: ['2026-10-20T18:00:00.000Z'],
    maxDistanceKm: 5, minSkillLevel: 2, maxSkillLevel: 5, playingStyles: ['Attack'],
  };
  let prisma: any;
  let availability: { getUpcomingTimeSlots: jest.Mock };
  let provider: DatabaseCandidateProvider;
  let http: { post: jest.Mock };
  let gateway: MatchmakingService;

  beforeEach(() => {
    prisma = {
      playerProfile: {
        findUnique: jest.fn().mockResolvedValue(profile(1, null, null)),
        findMany: jest.fn().mockResolvedValue([
          profile(2, 16.01, 108), profile(3, 16.2, 108), profile(4, 16.02, 108),
        ]),
      },
      playingPreference: {
        findUnique: jest.fn().mockResolvedValue({ minSkillLevel: 1, maxSkillLevel: 4, maxDistanceKm: 20 }),
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    availability = { getUpcomingTimeSlots: jest.fn(async (id: number) =>
      id === 4 ? [] : ['2026-10-20T18:00:00.000Z']) };
    prisma.playerProfile.findMany.mockResolvedValueOnce([
      profile(2, 16.01, 108), profile(3, 16.2, 108), profile(4, 16.02, 108),
    ]).mockResolvedValue([{
      userId: 2, nickname: null, avatarUrl: null, skillLevel: null,
      user: { fullName: 'Fixture player' },
    }]);
    provider = new DatabaseCandidateProvider(new CandidatesService(
      prisma, availability as unknown as AvailabilityService,
      { getReliabilityScores: async (ids: number[]) => new Map(ids.map((id) => [id, 5])) } as unknown as RatingsService,
    ), prisma, availability as unknown as AvailabilityService);
    http = { post: jest.fn().mockResolvedValue({ status: 200, data: {
      matched_users: [{ user_id: '2', match_score: 90, breakdown: { skill_score: 90, distance_score: 80, time_score: 70, reliability_score: 60, style_score: 50 } }], total_candidates_processed: 1,
    } }) };
    const config = new ConfigService({ MATCHMAKING_API_URL: 'http://matchmaking.test/api/v1/match' });
    gateway = new MatchmakingService(provider, new FastApiClient(http as any, config), prisma, { recordSession: jest.fn() } as unknown as RecommendationHistoryService);
  });

  it('uses real candidate search and maps backend skills plus request criteria to FastAPI', async () => {
    await expect(gateway.getRecommendedMatches(1, criteria)).resolves.toEqual({
      matchedUsers: [{ userId: '2', matchScore: 90, breakdown: { skill_score: 90, distance_score: 80, time_score: 70, reliability_score: 60, style_score: 50 }, profile: {
        fullName: 'Fixture player', nickname: null, avatarUrl: null, skillLevel: null,
      } }], totalCandidatesProcessed: 1,
    });
    const payload = http.post.mock.calls[0][1];
    expect(payload.current_user).toMatchObject({
      user_id: '1', location: criteria.location,
      available_time_slots: criteria.availableTimeSlots, max_distance_km: 5,
      skill: { smash: 4, net_play: 4, preferred_min: 2, preferred_max: 5 },
      playing_style: ['Attack'],
    });
    expect(payload.candidates.map((candidate: any) => candidate.user_id)).toEqual(['2']);
    expect(prisma.playerProfile.findMany.mock.calls[0][0].where.userId).toEqual({ not: 1 });
    expect(prisma.playerProfile.findMany).toHaveBeenCalledTimes(2);
    expect(prisma.playerProfile.findMany.mock.calls[1][0].where).toEqual({
      userId: { in: [2] }, locationSharingEnabled: true, user: { role: { name: 'PLAYER' } },
    });
  });

  it('uses host match rules instead of request preferences and drops existing roster members', async () => {
    const weekly = [{ dayOfWeek: 1, startTime: '18:00' }];
    const withWeekly = (id: number, latitude: number) => ({
      ...profile(id, latitude, 108), user: { availabilities: weekly },
    });
    prisma.match = { findUnique: jest.fn().mockResolvedValue({
      hostId: 1, privacy: 'OPEN', status: 'OPEN', startTime: new Date(Date.now() + 300000),
      maxPlayers: 4, minSkillLevel: 1, maxSkillLevel: 5,
      participants: [{ userId: 1, status: 'ACCEPTED' }, { userId: 2, status: 'INVITED' }],
    }) };
    prisma.playerProfile.findFirst = jest.fn().mockResolvedValue(withWeekly(1, 16));
    prisma.playerProfile.findMany.mockReset()
      .mockResolvedValueOnce([withWeekly(2, 16.01), withWeekly(3, 16.02)])
      .mockResolvedValueOnce([withWeekly(3, 16.02)]);
    const result = await provider.getCandidates(1, {
      ...criteria, matchId: 123, maxDistanceKm: 1, minSkillLevel: 5, maxSkillLevel: 5,
    });
    expect(result.currentUser.skill.preferredMin).toBe(1);
    expect(result.currentUser.maxDistanceKm).toBe(5);
    expect(result.candidates.map((row) => row.userId)).toEqual(['3']);
    expect(prisma.playerProfile.findMany.mock.calls[1][0].where.userId).toEqual({ in: [3] });
  });

  it('skips FastAPI when the database has no nearby candidates', async () => {
    prisma.playerProfile.findMany.mockReset().mockResolvedValue([]);
    await expect(gateway.getRecommendedMatches(1, criteria)).resolves.toEqual({
      matchedUsers: [], totalCandidatesProcessed: 0,
    });
    expect(http.post).not.toHaveBeenCalled();
  });

  it('does not write profiles and does not call FastAPI when candidate lookup fails', async () => {
    prisma.playerProfile.findUnique.mockRejectedValue(new Error('private database details'));
    await expect(gateway.getRecommendedMatches(1, criteria)).rejects.toMatchObject({ status: 503 });
    expect(http.post).not.toHaveBeenCalled();
  });

  it('boots the complete application with the database provider and Candidates routes registered', async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(FASTAPI_HTTP).useValue(http)
      .overrideProvider(AUTH_JWT_CONFIG).useValue({
        accessSecret: 'a'.repeat(32), refreshSecret: 'b'.repeat(32), issuer: 'test',
        accessAudience: 'test-api', refreshAudience: 'test-refresh',
      }).compile();
    const app = module.createNestApplication();
    try {
      await app.init();
      expect(module.get(CANDIDATE_PROVIDER)).toBeInstanceOf(DatabaseCandidateProvider);
      const routes = app.getHttpAdapter().getInstance()._router.stack
        .filter((layer: any) => layer.route).map((layer: any) => layer.route.path);
      expect(routes).toEqual(expect.arrayContaining([
        '/matchmaking/recommend', '/candidates/me/location', '/candidates/nearby',
      ]));
    } finally {
      await app.close();
    }
  });
});
