import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { AppModule } from '../app.module';
import { AUTH_JWT_CONFIG, AuthJwtConfig } from '../auth/jwt.config';
import { AuthTokensService } from '../auth/auth-tokens.service';
import { Role } from '../auth/roles.enum';
import { PrismaService } from '../prisma/prisma.service';
import { AvailabilityService } from '../availability-preference/availability.service';
import { RatingsService } from '../ratings/ratings.service';

describe('Player location privacy HTTP', () => {
  let app: INestApplication;
  let tokens: AuthTokensService;
  const sessions = new Map<string, any>();
  const profiles = new Map<number, any>();
  const prisma = {
    refreshSession: { findUnique: jest.fn(async ({ where }) => sessions.get(where.id) ?? null) },
    playerProfile: {
      findUnique: jest.fn(async ({ where }) => profiles.get(where.userId) ?? null),
      upsert: jest.fn(async ({ where, create, update }) => {
        const p = profiles.get(where.userId) ?? { locationSharingEnabled: false, ...create };
        Object.assign(p, update); profiles.set(where.userId, p); return p;
      }),
      findMany: jest.fn(async ({ where }) => [...profiles.values()].filter(p =>
        p.userId !== where.userId.not && p.locationSharingEnabled === where.locationSharingEnabled)),
    },
    playingPreference: { findUnique: jest.fn(async () => null), findMany: jest.fn(async () => []) },
  };
  const jwtConfig: AuthJwtConfig = {
    accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
    issuer: 'privacy-test', accessAudience: 'test-api', refreshAudience: 'test-refresh',
  };
  const profile = (userId: number, enabled = false) => ({
    userId, latitude: 16 + userId / 1000, longitude: 108, locationSharingEnabled: enabled,
    nickname: null, skillLevel: null, skill: null, user: { id: userId, fullName: `Player ${userId}` },
  });
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(AvailabilityService).useValue({ getUpcomingTimeSlots: jest.fn(async () => ['2026-10-20T18:00:00Z']) })
      .overrideProvider(RatingsService).useValue({ getReliabilityScores: jest.fn(async (ids: number[]) => new Map(ids.map(id => [id, 5]))) })
      .overrideProvider(AUTH_JWT_CONFIG).useValue(jwtConfig).compile();
    tokens = module.get(AuthTokensService);
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    await app.init();
  });
  afterAll(async () => { await app.close(); });
  beforeEach(() => {
    sessions.clear(); profiles.clear();
    profiles.set(1, profile(1)); profiles.set(2, profile(2)); profiles.set(3, profile(3, true));
  });
  async function token(id: number, role = Role.PLAYER) {
    const sid = randomUUID(), expiresAt = new Date(Date.now() + 60000);
    sessions.set(sid, { userId: id, expiresAt, revokedAt: null, user: { id, email: 'test@example.test', role: { name: role } } });
    return (await tokens.issuePair({ id, email: 'test@example.test', role }, sid, expiresAt)).accessToken;
  }
  it('requires valid PLAYER sessions and rejects attempted changes for another user', async () => {
    await request(app.getHttpServer()).put('/candidates/me/location-sharing').send({ enabled: true }).expect(401);
    const owner = await token(9, Role.OWNER);
    await request(app.getHttpServer()).put('/candidates/me/location-sharing').auth(owner, { type: 'bearer' }).send({ enabled: true }).expect(403);
    await request(app.getHttpServer()).put('/candidates/me/location').auth(owner, { type: 'bearer' }).send({ latitude: 16, longitude: 108 }).expect(403);
    const player = await token(1);
    await request(app.getHttpServer()).put('/candidates/me/location-sharing').auth(player, { type: 'bearer' }).send({ enabled: true, userId: 2 }).expect(400);
    await request(app.getHttpServer()).put('/candidates/me/location-sharing').auth(player, { type: 'bearer' }).send({ enabled: 'true' }).expect(400);
    expect(profiles.get(2).locationSharingEnabled).toBe(false);
  });
  it('filters consent, preserves distance and hides coordinates in both public endpoints, including after revocation', async () => {
    const viewer = await token(1), candidate = await token(2);
    const getNearby = () => request(app.getHttpServer()).get('/candidates/nearby').auth(viewer, { type: 'bearer' });
    let response = await getNearby().expect(200);
    expect(response.body.candidates.map((p: any) => p.userId)).toEqual([3]);
    await request(app.getHttpServer()).get('/candidates/me/location-sharing').auth(candidate, { type: 'bearer' }).expect(200, { enabled: false });
    await request(app.getHttpServer()).put('/candidates/me/location-sharing').auth(candidate, { type: 'bearer' }).send({ enabled: true }).expect(200, { enabled: true });
    response = await getNearby().expect(200);
    expect(response.body.candidates.map((p: any) => p.userId)).toEqual([2, 3]);
    expect(response.body.candidates[0].distanceKm).toBeGreaterThan(0);
    expect(JSON.stringify(response.body)).not.toMatch(/latitude|longitude/);
    const payload = await request(app.getHttpServer()).get('/candidates/matchmaking-request').auth(viewer, { type: 'bearer' }).expect(200);
    expect(payload.body.request.candidates).toHaveLength(2);
    expect(JSON.stringify(payload.body.request.candidates)).not.toMatch(/latitude|longitude|location/);
    await request(app.getHttpServer()).put('/candidates/me/location-sharing').auth(candidate, { type: 'bearer' }).send({ enabled: false }).expect(200, { enabled: false });
    response = await getNearby().expect(200);
    expect(response.body.candidates.map((p: any) => p.userId)).toEqual([3]);
  });
  it('updating coordinates never opts a player in', async () => {
    const candidate = await token(2);
    await request(app.getHttpServer()).put('/candidates/me/location').auth(candidate, { type: 'bearer' }).send({ latitude: 16.1, longitude: 108.1 }).expect(200);
    expect(profiles.get(2).locationSharingEnabled).toBe(false);
    expect(profiles.get(2).latitude).toBe(16.1);
  });
});
