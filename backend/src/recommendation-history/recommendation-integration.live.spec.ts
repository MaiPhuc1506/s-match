import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { AppModule } from '../app.module';
import { AUTH_JWT_CONFIG } from '../auth/jwt.config';
import { PrismaService } from '../prisma/prisma.service';

// Explicit opt-in: uses a migrated database and a running FastAPI service.
// Creates uniquely named accounts and removes only those accounts in teardown.
const live = process.env.RUN_RECOMMENDATION_LIVE === '1' ? describe : describe.skip;
live('Recommendation integration (real PostgreSQL, FastAPI and authentication)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let config: ConfigService;
  const ids: number[] = [];
  const tokens: string[] = [];
  let criteria: any;
  let upstream: string;
  const location = { latitude: -55, longitude: -120 };

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(AUTH_JWT_CONFIG).useValue({
        accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
        issuer: 'recommendation-live-test', accessAudience: 's-match-api', refreshAudience: 's-match-refresh',
      }).compile();
    prisma = module.get(PrismaService);
    config = module.get(ConfigService);
    upstream = config.get<string>('MATCHMAKING_API_URL')!;
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    await app.init();
    for (let i = 0; i < 3; i++) {
      const email = `recommendation-${randomUUID()}@example.test`;
      const password = randomBytes(18).toString('hex');
      const registered = await request(app.getHttpServer()).post('/auth/register')
        .send({ email, password, fullName: `Integration player ${i}` }).expect(201);
      const id = registered.body.data.id;
      ids.push(id);
      const loggedIn = await request(app.getHttpServer()).post('/auth/login').send({ email, password }).expect(201);
      tokens.push(loggedIn.body.accessToken);
      await prisma.playerProfile.create({ data: {
        userId: id, ...location, longitude: location.longitude + i * 0.001,
        nickname: `Integration ${i}`, avatarUrl: 'https://example.test/avatar.png', skillLevel: 'INTERMEDIATE',
        skill: { create: { smash: 3, defense: 3, netPlay: 3, stamina: 3, footwork: 3, serve: 3 } },
      } });
      await prisma.availability.createMany({ data: Array.from({ length: 7 }, (_, dayOfWeek) => ({
        userId: id, dayOfWeek, startTime: '18:00', endTime: '19:00',
      })) });
    }
    const slots = await api('get', `/availability/${ids[0]}/upcoming-slots`).expect(200);
    criteria = { location, availableTimeSlots: slots.body, maxDistanceKm: 5, minSkillLevel: 1, maxSkillLevel: 5 };
  }, 30000);

  afterAll(async () => {
    try {
      if (prisma && ids.length) {
        await prisma.availability.deleteMany({ where: { userId: { in: ids } } });
        await prisma.user.deleteMany({ where: { id: { in: ids } } });
      }
    } finally {
      await app?.close();
      await prisma?.$disconnect();
    }
  });

  function api(method: 'get' | 'post' | 'patch' | 'delete', path: string, account = 0) {
    return request(app.getHttpServer())[method](path).auth(tokens[account], { type: 'bearer' });
  }

  it('searches, persists final ranks, protects ownership, updates stats and deletes history', async () => {
    const recommended = await api('post', '/matchmaking/recommend').send(criteria).expect(200);
    expect(recommended.body.matchedUsers).toHaveLength(2);
    expect(recommended.body.matchedUsers[0].profile.nickname).toBe('Integration 1');
    const list = await api('get', '/recommendations/history?page=1&limit=1').expect(200);
    expect(list.body).toMatchObject({ total: 1, page: 1, limit: 1, totalPages: 1 });
    const session = list.body.items[0];
    expect(session.criteria).toEqual(criteria);
    expect(session.results.map((r: any) => [String(r.recommendedUserId), r.matchScore, r.rank]))
      .toEqual(recommended.body.matchedUsers.map((r: any, i: number) => [r.userId, r.matchScore, i + 1]));
    const path = `/recommendations/history/${session.id}`;
    await api('get', path).expect(200);
    await api('get', path, 1).expect(404);
    await api('delete', path, 1).expect(404);
    const resultPath = `${path}/results/${session.results[0].id}`;
    await api('patch', resultPath, 1).send({ outcome: 'INVITED' }).expect(404);
    await api('patch', resultPath).send({ outcome: 'INVITED' }).expect(200);
    await api('patch', resultPath).send({ outcome: 'ACCEPTED' }).expect(200);
    await api('patch', resultPath).send({ outcome: 'SHOWN' }).expect(400);
    const stats = await api('get', '/recommendations/history/stats').expect(200);
    expect(stats.body).toMatchObject({ totalSessions: 1, totalRecommended: 2, invitationRate: 0.5, acceptanceRate: 1 });
    await api('delete', path).expect(200);
    await api('get', path).expect(404);
    expect(await prisma.recommendationResult.count({ where: { sessionId: session.id } })).toBe(0);
  });

  it('persists an empty search without inventing recommended players', async () => {
    const result = await api('post', '/matchmaking/recommend').send({ ...criteria, maxDistanceKm: 0 }).expect(200);
    expect(result.body.matchedUsers).toEqual([]);
    const list = await api('get', '/recommendations/history').expect(200);
    expect(list.body.items[0]).toMatchObject({ totalCandidatesProcessed: 0, results: [] });
  });

  it('does not save failed searches, rejects invalid criteria and revoked sessions', async () => {
    const count = await prisma.recommendationSession.count({ where: { userId: ids[0] } });
    try {
      config.set('MATCHMAKING_API_URL', 'http://127.0.0.1:1/api/v1/match');
      await api('post', '/matchmaking/recommend').send(criteria).expect(503);
    } finally {
      config.set('MATCHMAKING_API_URL', upstream);
    }
    await api('post', '/matchmaking/recommend').send({ ...criteria, minSkillLevel: 5, maxSkillLevel: 1 }).expect(400);
    await request(app.getHttpServer()).post('/matchmaking/recommend').send(criteria).expect(401);
    await api('post', '/auth/logout').expect(201);
    await api('post', '/matchmaking/recommend').send(criteria).expect(401);
    expect(await prisma.recommendationSession.count({ where: { userId: ids[0] } })).toBe(count);
  });
});
