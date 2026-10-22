import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { AppModule } from '../app.module';
import { AUTH_JWT_CONFIG } from '../auth/jwt.config';
import { AvailabilityService } from '../availability-preference/availability.service';
import { CandidatesService } from '../candidates/candidates.service';
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
        // Search coordinates work even when no last-known location has been saved.
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
    ));
    http = { post: jest.fn().mockResolvedValue({ status: 200, data: {
      matched_users: [{ user_id: '2', match_score: 90 }], total_candidates_processed: 1,
    } }) };
    const config = new ConfigService({ MATCHMAKING_API_URL: 'http://matchmaking.test/api/v1/match' });
    gateway = new MatchmakingService(provider, new FastApiClient(http as any, config), prisma, { recordSession: jest.fn() } as unknown as RecommendationHistoryService);
  });

  it('uses real candidate search and maps backend skills plus request criteria to FastAPI', async () => {
    await expect(gateway.getRecommendedMatches(1, criteria)).resolves.toEqual({
      matchedUsers: [{ userId: '2', matchScore: 90, profile: {
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
    // Candidate 3 is outside the radius; candidate 4 has no availability.
    expect(payload.candidates.map((candidate: any) => candidate.user_id)).toEqual(['2']);
    expect(prisma.playerProfile.findMany.mock.calls[0][0].where.userId).toEqual({ not: 1 });
    expect(prisma.playerProfile.findMany).toHaveBeenCalledTimes(2);
    expect(prisma.playerProfile.findMany.mock.calls[1][0].where).toEqual({
      userId: { in: [2] }, user: { role: { name: 'PLAYER' } },
    });
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
