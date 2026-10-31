import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { AuthTokensService } from '../auth/auth-tokens.service';
import { AUTH_JWT_CONFIG } from '../auth/jwt.config';
import { Role } from '../auth/roles.enum';
import { PrismaService } from '../prisma/prisma.service';
import { PrismaModule } from '../prisma/prisma.module';
import { MatchesModule } from './matches.module';
import { makeMatchFeedbackFixture } from '../../test/helpers/matches-feedback.fixture';

describe('SMM-34 Feedback HTTP (real guard/service, mock Prisma)', () => {
  let app: INestApplication;
  let tokens: AuthTokensService;
  let fixture: ReturnType<typeof makeMatchFeedbackFixture>;
  const prisma = makeMatchFeedbackFixture().prisma;
  const sessions = new Map<string, any>();
  const body = { recipientUserId: 30, rating: 5 };
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [PrismaModule, MatchesModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(AUTH_JWT_CONFIG).useValue({
        accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
        issuer: 'feedback-tests', accessAudience: 'api', refreshAudience: 'refresh',
      }).compile();
    tokens = module.get(AuthTokensService);
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
    await app.init();
  });
  afterAll(async () => { await app?.close(); });
  beforeEach(() => {
    fixture = makeMatchFeedbackFixture();
    Object.assign(prisma, fixture.prisma);
    sessions.clear();
    prisma.refreshSession.findUnique.mockImplementation(async ({ where }: any) => sessions.get(where.id) ?? null);
  });
  async function pair(id = 10, role = Role.PLAYER) {
    const sid = randomUUID(), expiresAt = new Date(Date.now() + 60000);
    sessions.set(sid, { userId: id, revokedAt: null, expiresAt, user: { id, role: { name: role } } });
    return tokens.issuePair({ id, role, email: 'fixture@example.test' }, sid, expiresAt);
  }
  async function send(data: any = body, id = 10, role = Role.PLAYER, match = '11') {
    return request(app.getHttpServer()).post(`/matches/${match}/feedback`)
      .auth((await pair(id, role)).accessToken, { type: 'bearer' }).send(data);
  }
  function safeError(response: any, status: number) {
    expect(response.status).toBe(status);
    expect(Object.keys(response.body).sort()).toEqual(['error', 'message', 'statusCode']);
    expect(JSON.stringify(response.body)).not.toMatch(/PRIVATE_|fixture@example|refreshToken|password|senderUserId/);
  }
  it.each([[10, 30], [30, 10]])('returns 201 for accepted host/member %s rating %s', async (sender, recipient) => {
    const before = structuredClone(fixture.rows);
    const response = await send({ ...body, recipientUserId: recipient }, sender);
    expect(response.status).toBe(201);
    expect(Object.keys(response.body).sort()).toEqual(['id', 'matchId', 'senderUserId', 'recipientUserId', 'rating', 'comment', 'createdAt'].sort());
    expect(response.body).toMatchObject({ matchId: 11, senderUserId: sender, recipientUserId: recipient, comment: null });
    expect(new Date(response.body.createdAt).getTime()).not.toBeNaN();
    expect(fixture.rows).toEqual(before);
  });
  it.each([Role.OWNER, Role.ADMIN])('rejects role %s without insert', async (role) => {
    safeError(await send(body, 10, role), 403);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
  it('rejects absent, refresh and revoked-session tokens', async () => {
    safeError(await request(app.getHttpServer()).post('/matches/11/feedback').send(body), 401);
    const auth = await pair();
    safeError(await request(app.getHttpServer()).post('/matches/11/feedback').auth(auth.refreshToken, { type: 'bearer' }).send(body), 401);
    for (const session of sessions.values()) session.revokedAt = new Date();
    safeError(await request(app.getHttpServer()).post('/matches/11/feedback').auth(auth.accessToken, { type: 'bearer' }).send(body), 401);
    expect(prisma.feedback.create).not.toHaveBeenCalled();
  });
  it.each([
    {}, { recipientUserId: 30 }, { rating: 5 },
    { ...body, recipientUserId: null }, { ...body, recipientUserId: '30' },
    { ...body, recipientUserId: 0 }, { ...body, recipientUserId: 1.5 }, { ...body, recipientUserId: 2147483648 },
    { ...body, rating: 0 }, { ...body, rating: 6 }, { ...body, rating: null }, { ...body, rating: 2.5 }, { ...body, rating: '5' },
    { ...body, comment: null }, { ...body, comment: 12 }, { ...body, comment: 'a'.repeat(501) },
  ])('rejects invalid request DTO before transaction %#', async (data) => {
    const response = await send(data);
    expect(response.status).toBe(400);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
  it.each(['senderUserId', 'hostId', 'sender', 'recipient', 'match'])('rejects injected field %s', async (key) => {
    expect((await send({ ...body, [key]: 99 })).status).toBe(400);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
  it.each(['abc', '0', '-1', '1.5', '2147483648'])('rejects Match ID %s', async (id) => {
    safeError(await send(body, 10, Role.PLAYER, id), 400);
    expect(prisma.feedback.create).not.toHaveBeenCalled();
  });
  it.each(['OPEN', 'FULL', 'IN_PROGRESS', 'CANCELLED'])('rejects state %s', async (state) => {
    fixture.privateMatch.status = state;
    safeError(await send(), 409);
    expect(prisma.feedback.create).not.toHaveBeenCalled();
  });
  it('rejects a future endTime', async () => {
    fixture.privateMatch.endTime = new Date(Date.now() + 60000);
    safeError(await send(), 409);
  });
  it('returns 404 for a missing Match', async () => { safeError(await send(body, 10, Role.PLAYER, '999'), 404); });
  it.each([40, 50, 60, 70, 99])('rejects sender %s outside accepted roster', async (id) => {
    safeError(await send(body, id), 403);
    expect(prisma.feedback.create).not.toHaveBeenCalled();
  });
  it.each([40, 50, 60, 70, 99])('rejects recipient %s outside accepted roster', async (id) => {
    safeError(await send({ ...body, recipientUserId: id }), 400);
    expect(prisma.feedback.create).not.toHaveBeenCalled();
  });
  it('rejects self feedback', async () => { safeError(await send({ ...body, recipientUserId: 10 }), 400); });
  it('returns 201/409 for concurrent duplicates with only one insert committed', async () => {
    const auth = await pair();
    const responses = await Promise.all([0, 1].map(() => request(app.getHttpServer()).post('/matches/11/feedback')
      .auth(auth.accessToken, { type: 'bearer' }).send(body)));
    expect(responses.map((r) => r.status).sort()).toEqual([201, 409]);
    expect(fixture.feedbacks).toHaveLength(1);
    safeError(responses.find((r) => r.status === 409), 409);
  });
  it('sanitizes database failure and rolls back', async () => {
    prisma.feedback.create.mockImplementationOnce(async () => {
      fixture.feedbacks.push({ id: 1 }); throw new Error('PRIVATE_DATABASE_ERROR');
    });
    safeError(await send(), 500);
    expect(fixture.feedbacks).toHaveLength(0);
    expect(fixture.events).toContain('rollback');
  });
});
