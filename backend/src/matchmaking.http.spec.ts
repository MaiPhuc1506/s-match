import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { MatchmakingModule } from './matchmaking.module';
import { MatchmakingService } from './matchmaking.service';
import { CANDIDATE_PROVIDER } from './matchmaking/candidate-provider';
import { FASTAPI_HTTP } from './matchmaking/fastapi.client';
import { AuthTokensService } from './auth/auth-tokens.service';
import { AUTH_JWT_CONFIG, AuthJwtConfig } from './auth/jwt.config';
import { Role } from './auth/roles.enum';
import { PrismaModule } from './prisma/prisma.module';
import { PrismaService } from './prisma/prisma.service';
import { candidateData, fastApiResponse, findPlayerRequest, recommendationProfile } from '../test/helpers/matchmaking.fixture';

describe('SMM-26 Gateway HTTP (real guard/service/client, mocked Prisma/provider/HTTP)', () => {
  let app: INestApplication;
  let tokens: AuthTokensService;
  const provider = { getCandidates: jest.fn() };
  const http = { post: jest.fn() };
  const prisma = { user: { findMany: jest.fn() }, recommendationSession: { create: jest.fn() }, refreshSession: { findUnique: jest.fn() }, playerProfile: { findMany: jest.fn() } };
  const sessions = new Map<string, any>();
  const config = { get: (key: string) => ({ MATCHMAKING_API_URL: 'http://matchmaking.test/api/v1/match', MATCHMAKING_TIMEOUT_MS: 30 })[key] };
  const jwtConfig: AuthJwtConfig = {
    accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
    issuer: 'matchmaking-http-test', accessAudience: 'test-api', refreshAudience: 'test-refresh',
  };
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [PrismaModule, MatchmakingModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(CANDIDATE_PROVIDER).useValue(provider)
      .overrideProvider(FASTAPI_HTTP).useValue(http)
      .overrideProvider(ConfigService).useValue(config)
      .overrideProvider(AUTH_JWT_CONFIG).useValue(jwtConfig).compile();
    tokens = module.get(AuthTokensService);
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    await app.init();
  });
  afterAll(async () => { await app?.close(); });
  beforeEach(() => {
    jest.resetAllMocks();
    sessions.clear();
    prisma.user.findMany.mockImplementation(async ({ where }: any) => where.id.in.map((id: number) => ({ id })));
    prisma.recommendationSession.create.mockImplementation(async ({ data }: any) => ({ id: 1, ...data }));
    prisma.refreshSession.findUnique.mockImplementation(async ({ where }: any) => sessions.get(where.id) ?? null);
    provider.getCandidates.mockResolvedValue(candidateData());
    http.post.mockResolvedValue({ status: 200, data: fastApiResponse() });
    prisma.playerProfile.findMany.mockResolvedValue([recommendationProfile(3), recommendationProfile(7)]);
  });
  async function pair(role = Role.PLAYER) {
    const sid = randomUUID(), expiresAt = new Date(Date.now() + 60000);
    sessions.set(sid, { userId: 8, expiresAt, revokedAt: null, user: { id: 8, email: 'fixture@example.test', role: { name: role } } });
    return tokens.issuePair({ id: 8, email: 'fixture@example.test', role }, sid, expiresAt);
  }
  async function post(body: object = findPlayerRequest, role = Role.PLAYER) {
    return request(app.getHttpServer()).post('/matchmaking/recommend').auth((await pair(role)).accessToken, { type: 'bearer' }).send(body);
  }
  function noDependencies() {
    expect(prisma.recommendationSession.create).not.toHaveBeenCalled();
    expect(provider.getCandidates).not.toHaveBeenCalled();
    expect(http.post).not.toHaveBeenCalled();
    expect(prisma.playerProfile.findMany).not.toHaveBeenCalled();
  }
  function safeError(response: any, status: number) {
    expect(response.status).toBe(status);
    expect(Object.keys(response.body).sort()).toEqual(['error', 'message', 'statusCode']);
    expect(JSON.stringify(response.body)).not.toMatch(/PRIVATE_|fixture@example|matchmaking\.test|not-a-token|Bearer /);
  }

  it('returns 200 for PLAYER using authenticated identity and a safe, ordered result', async () => {
    const response = await post();
    expect(response.status).toBe(200);
    expect(provider.getCandidates).toHaveBeenCalledWith(8, expect.objectContaining(findPlayerRequest));
    expect(http.post.mock.calls[0][1].current_user.user_id).toBe('8');
    expect(response.body).toEqual({ matchedUsers: [
      { userId: '7', matchScore: 85, profile: { fullName: 'Fixture player 7', nickname: null, avatarUrl: null, skillLevel: null } },
      { userId: '3', matchScore: 80, profile: { fullName: 'Fixture player 3', nickname: null, avatarUrl: null, skillLevel: null } },
    ], totalCandidatesProcessed: 2 });
    expect(provider.getCandidates).toHaveBeenCalledTimes(1);
    expect(http.post).toHaveBeenCalledTimes(1);
    expect(prisma.playerProfile.findMany).toHaveBeenCalledTimes(1);
    expect(prisma.playerProfile.findMany.mock.calls[0][0].where).toEqual({
      userId: { in: [7, 3] }, user: { role: { name: 'PLAYER' } },
    });
  });
  it('persists the authenticated search and ordered displayed results through the real history service', async () => {
    const response = await post();
    expect(response.status).toBe(200);
    expect(prisma.recommendationSession.create).toHaveBeenCalledTimes(1);
    expect(prisma.recommendationSession.create.mock.calls[0][0].data).toMatchObject({
      userId: 8, criteria: findPlayerRequest,
      results: { create: response.body.matchedUsers.map((row: any, index: number) => ({
        recommendedUserId: Number(row.userId), matchScore: row.matchScore, rank: index + 1,
      })) },
    });
  });
  it('does not return successful recommendations when history storage is unavailable', async () => {
    prisma.recommendationSession.create.mockRejectedValue(new Error('PRIVATE_DATABASE_DETAILS'));
    safeError(await post(), 503);
  });
  it('returns 401 without JWT before any dependency call', async () => {
    safeError(await request(app.getHttpServer()).post('/matchmaking/recommend').send(findPlayerRequest), 401);
    noDependencies();
  });
  it.each([Role.OWNER, Role.ADMIN])('returns 403 for %s before any dependency call', async (role) => {
    safeError(await post(findPlayerRequest, role), 403);
    noDependencies();
  });
  it('rejects malformed, refresh-type and revoked-session tokens', async () => {
    const auth = await pair();
    for (const token of ['invalid-fixture-token', auth.refreshToken]) {
      safeError(await request(app.getHttpServer()).post('/matchmaking/recommend').auth(token, { type: 'bearer' }).send(findPlayerRequest), 401);
    }
    for (const session of sessions.values()) session.revokedAt = new Date();
    safeError(await request(app.getHttpServer()).post('/matchmaking/recommend').auth(auth.accessToken, { type: 'bearer' }).send(findPlayerRequest), 401);
    noDependencies();
  });
  it('checks the current database role rather than a stale PLAYER JWT claim', async () => {
    const auth = await pair();
    for (const session of sessions.values()) session.user.role.name = Role.ADMIN;
    safeError(await request(app.getHttpServer()).post('/matchmaking/recommend').auth(auth.accessToken, { type: 'bearer' }).send(findPlayerRequest), 403);
    noDependencies();
  });
  it.each([
    {}, { availableTimeSlots: [] }, { availableTimeSlots: ['invalid'] },
    { availableTimeSlots: ['2026-10-20T18:00:00'] }, { availableTimeSlots: ['2026-02-30T18:00:00Z'] },
    { availableTimeSlots: null }, { location: null }, { location: [] },
    { location: { latitude: 91, longitude: 108 } }, { location: { latitude: 16, longitude: -181 } },
    { location: { latitude: '16', longitude: 108 } }, { maxDistanceKm: -1 }, { maxDistanceKm: null },
    { minSkillLevel: 0 }, { maxSkillLevel: 6 }, { minSkillLevel: 2.5 },
    { minSkillLevel: null }, { playingStyles: [1] }, { playingStyles: null },
    { minSkillLevel: 5, maxSkillLevel: 2 },
  ])('returns 400 for invalid DTO without dependencies: %j', async (body) => {
    safeError(await post(Object.keys(body).length ? { ...findPlayerRequest, ...body } : {}), 400);
    noDependencies();
  });
  it.each([
    { userId: 1 }, { current_user: { user_id: '1' } }, { candidates: [] },
    { accessToken: 'not-a-token' }, { url: 'http://not-allowed.test' },
    { location: { latitude: 16, longitude: 108, secret: 'not-allowed' } },
  ])('blocks client identity/candidate/extra-field injection', async (body) => {
    safeError(await post({ ...findPlayerRequest, ...body }), 400);
    noDependencies();
  });
  it('passes valid optional search preferences to backend provider', async () => {
    const body = { ...findPlayerRequest, maxDistanceKm: 0, minSkillLevel: 1, maxSkillLevel: 5, playingStyles: ['aggressive'] };
    expect((await post(body)).status).toBe(200);
    expect(provider.getCandidates).toHaveBeenCalledWith(8, expect.objectContaining(body));
  });
  it('returns 503 and skips FastAPI on provider failure', async () => {
    provider.getCandidates.mockRejectedValueOnce(new Error('PRIVATE_PROVIDER_DETAILS'));
    safeError(await post(), 503);
    expect(http.post).not.toHaveBeenCalled();
  });
  it('rejects mismatched provider identity without exposing its data', async () => {
    const data = candidateData();
    data.currentUser.userId = '1';
    provider.getCandidates.mockResolvedValueOnce(data);
    safeError(await post(), 502);
    expect(http.post).not.toHaveBeenCalled();
  });
  it('returns empty success when backend has no candidates, without FastAPI', async () => {
    provider.getCandidates.mockResolvedValueOnce({ ...candidateData(), candidates: [] });
    const response = await post();
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ matchedUsers: [], totalCandidatesProcessed: 0 });
    expect(http.post).not.toHaveBeenCalled();
    expect(prisma.playerProfile.findMany).not.toHaveBeenCalled();
  });
  it('returns empty success when FastAPI finds no compatible candidates', async () => {
    http.post.mockResolvedValueOnce({ status: 200, data: { matched_users: [], total_candidates_processed: 2 } });
    const response = await post();
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ matchedUsers: [], totalCandidatesProcessed: 2 });
    expect(prisma.playerProfile.findMany).not.toHaveBeenCalled();
  });
  it.each([
    [{ isAxiosError: true, code: 'ETIMEDOUT', message: 'PRIVATE_DETAILS' }, 504],
    [{ isAxiosError: true, code: 'ECONNREFUSED', message: 'PRIVATE_DETAILS' }, 503],
    [{ isAxiosError: true, response: { status: 500, data: 'PRIVATE_DETAILS' } }, 502],
  ])('sanitizes FastAPI errors as HTTP %s', async (error, status) => {
    http.post.mockRejectedValueOnce(error);
    safeError(await post(), status);
    expect(http.post).toHaveBeenCalledTimes(1);
  });
  it('rejects invalid FastAPI body with 502', async () => {
    http.post.mockResolvedValueOnce({ status: 200, data: { secret: 'PRIVATE_DETAILS' } });
    safeError(await post(), 502);
  });
  it('does not expose private keys added by either upstream dependency', async () => {
    const body = fastApiResponse();
    Object.assign(body, { password: 'PRIVATE_DETAILS' });
    Object.assign(body.matched_users[0], { email: 'PRIVATE_DETAILS', phone: 'PRIVATE_DETAILS' });
    http.post.mockResolvedValueOnce({ status: 200, data: body });
    const response = await post();
    expect(response.status).toBe(200);
    expect(Object.keys(response.body).sort()).toEqual(['matchedUsers', 'totalCandidatesProcessed']);
    for (const entry of response.body.matchedUsers) {
      expect(Object.keys(entry).sort()).toEqual(['matchScore', 'profile', 'userId']);
      expect(Object.keys(entry.profile).sort()).toEqual(['avatarUrl', 'fullName', 'nickname', 'skillLevel']);
    }
    expect(JSON.stringify(response.body)).not.toContain('PRIVATE_DETAILS');
  });
  it('omits deleted profiles and non-PLAYER users without changing processed count', async () => {
    prisma.playerProfile.findMany.mockImplementation(async ({ where }: any) => [
      { ...recommendationProfile(7), role: Role.ADMIN },
      { ...recommendationProfile(3), role: Role.PLAYER },
    ].filter((profile) => where.userId.in.includes(profile.userId) && where.user.role.name === profile.role));
    const response = await post();
    expect(response.status).toBe(200);
    expect(response.body.matchedUsers.map((row: any) => row.userId)).toEqual(['3']);
    expect(response.body.totalCandidatesProcessed).toBe(2);
    prisma.playerProfile.findMany.mockResolvedValueOnce([]);
    const empty = await post();
    expect(empty.status).toBe(200);
    expect(empty.body).toEqual({ matchedUsers: [], totalCandidatesProcessed: 2 });
  });
  it('returns only the public allowlist even if the database mock supplies private fields', async () => {
    prisma.playerProfile.findMany.mockResolvedValue([{
      ...recommendationProfile(7), nickname: 'Seven', avatarUrl: 'https://example.test/avatar.png', skillLevel: 'BEGINNER',
      latitude: 16, longitude: 108, metadata: 'PRIVATE_DETAILS',
      user: { fullName: null, email: 'PRIVATE_DETAILS', phone: 'PRIVATE_DETAILS', password: 'PRIVATE_DETAILS', refreshSessions: [] },
    }]);
    const response = await post();
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ matchedUsers: [{ userId: '7', matchScore: 85, profile: {
      fullName: null, nickname: 'Seven', avatarUrl: 'https://example.test/avatar.png', skillLevel: 'BEGINNER',
    } }], totalCandidatesProcessed: 2 });
    expect(prisma.playerProfile.findMany.mock.calls[0][0].select).toEqual({
      userId: true, nickname: true, avatarUrl: true, skillLevel: true, user: { select: { fullName: true } },
    });
  });
  it('returns sanitized 503 on profile failure, without retrying', async () => {
    prisma.playerProfile.findMany.mockRejectedValueOnce(new Error('PRIVATE_DATABASE_DETAILS'));
    safeError(await post(), 503);
    expect(prisma.playerProfile.findMany).toHaveBeenCalledTimes(1);
    expect(http.post).toHaveBeenCalledTimes(1);
  });
  it.each([
    { matched_users: [{ user_id: '7', match_score: 85 }, { user_id: '7', match_score: 80 }] },
    { matched_users: [{ user_id: '999', match_score: 85 }] },
    { matched_users: [{ user_id: '8', match_score: 85 }] },
  ])('preserves upstream identity validation before profile queries', async ({ matched_users }) => {
    http.post.mockResolvedValueOnce({ status: 200, data: { matched_users, total_candidates_processed: 2 } });
    safeError(await post(), 502);
    expect(prisma.playerProfile.findMany).not.toHaveBeenCalled();
  });
});

describe('MatchmakingModule default production wiring (no PostgreSQL/FastAPI)', () => {
  it('binds the unavailable provider rather than a production mock', async () => {
    const module = await Test.createTestingModule({ imports: [PrismaModule, MatchmakingModule] })
      .overrideProvider(PrismaService).useValue({})
      .overrideProvider(AUTH_JWT_CONFIG).useValue({
        accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
        issuer: 'default-provider-test', accessAudience: 'api', refreshAudience: 'refresh',
      }).compile();
    try {
      await expect(module.get(MatchmakingService).getRecommendedMatches(8, findPlayerRequest)).rejects.toMatchObject({ status: 503 });
    } finally { await module.close(); }
  });
});
