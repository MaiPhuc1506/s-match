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
import { makeMatchLifecycleFixture } from '../../test/helpers/matches-lifecycle.fixture';
import { expectSafeMatchResponse } from '../../test/helpers/matches-security.fixture';

describe('SMM-34 lifecycle HTTP (real guard/service; simulated transactions, no PostgreSQL)', () => {
  let app: INestApplication;
  let tokens: AuthTokensService;
  let fixture: ReturnType<typeof makeMatchLifecycleFixture>;
  const prisma = makeMatchLifecycleFixture().prisma;
  const sessions = new Map<string, any>();
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [PrismaModule, MatchesModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(AUTH_JWT_CONFIG).useValue({
        accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
        issuer: 'lifecycle-tests', accessAudience: 'api', refreshAudience: 'refresh',
      }).compile();
    tokens = module.get(AuthTokensService);
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
    await app.init();
  });
  afterAll(async () => { await app?.close(); });
  beforeEach(() => {
    fixture = makeMatchLifecycleFixture();
    fixture.privateMatch.endTime = new Date(Date.now() - 1000);
    Object.assign(prisma, fixture.prisma);
    sessions.clear();
    prisma.refreshSession.findUnique.mockImplementation(async ({ where }: any) => sessions.get(where.id) ?? null);
  });
  async function pair(id = 10, role = Role.PLAYER) {
    const sid = randomUUID(), expiresAt = new Date(Date.now() + 60000);
    sessions.set(sid, { userId: id, revokedAt: null, expiresAt, user: { id, role: { name: role } } });
    return tokens.issuePair({ id, role, email: 'fixture@example.test' }, sid, expiresAt);
  }
  async function complete(id = 10, role = Role.PLAYER, path = '11') {
    return request(app.getHttpServer()).patch(`/matches/${path}/complete`)
      .auth((await pair(id, role)).accessToken, { type: 'bearer' });
  }
  function safeError(response: any, status: number) {
    expect(response.status).toBe(status);
    expect(Object.keys(response.body).sort()).toEqual(['error', 'message', 'statusCode']);
    expect(JSON.stringify(response.body)).not.toMatch(/PRIVATE_|fixture@example|Bearer /);
  }

  it.each(['OPEN', 'FULL', 'IN_PROGRESS'])('returns 200 for a host completing %s without Booking/participant changes', async (status) => {
    fixture.privateMatch.status = status;
    const participants = structuredClone(fixture.privateMatch.participants);
    const bookings = structuredClone([...fixture.bookings]);
    const response = await complete();
    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({ id: 11, status: 'COMPLETED', hostId: 10 });
    expectSafeMatchResponse(response.body);
    expect(fixture.privateMatch.participants).toEqual(participants);
    expect([...fixture.bookings]).toEqual(bookings);
  });
  it.each([Role.PLAYER, Role.OWNER, Role.ADMIN])('has no host bypass for another user with role %s', async (role) => {
    safeError(await complete(80, role), 403);
    expect(prisma.match.updateMany).not.toHaveBeenCalled();
  });
  it('uses the JWT identity even if a request body supplies hostId', async () => {
    const response = await request(app.getHttpServer()).patch('/matches/11/complete')
      .auth((await pair(30)).accessToken, { type: 'bearer' }).send({ hostId: 10 });
    safeError(response, 403);
    expect(prisma.match.updateMany).not.toHaveBeenCalled();
  });
  it.each(['COMPLETED', 'CANCELLED'])('returns 409 for %s without writes', async (status) => {
    fixture.privateMatch.status = status;
    safeError(await complete(), 409);
    expect(prisma.match.updateMany).not.toHaveBeenCalled();
  });
  it('returns 409 before endTime', async () => {
    fixture.privateMatch.endTime = new Date(Date.now() + 60000);
    safeError(await complete(), 409);
    expect(prisma.match.updateMany).not.toHaveBeenCalled();
  });
  it('returns 404 for a missing Match', async () => { safeError(await complete(10, Role.PLAYER, '999'), 404); });
  it.each(['invalid', '0', '-1', '1.5', '2147483648'])('returns 400 for ID %s', async (id) => {
    safeError(await complete(10, Role.PLAYER, id), 400);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
  it('rejects missing, refresh-type and revoked-session credentials before transaction', async () => {
    safeError(await request(app.getHttpServer()).patch('/matches/11/complete'), 401);
    const auth = await pair();
    safeError(await request(app.getHttpServer()).patch('/matches/11/complete').auth(auth.refreshToken, { type: 'bearer' }), 401);
    for (const session of sessions.values()) session.revokedAt = new Date();
    safeError(await request(app.getHttpServer()).patch('/matches/11/complete').auth(auth.accessToken, { type: 'bearer' }), 401);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
  it('rejects an expired access token before transaction', async () => {
    const auth = await pair();
    const clock = jest.spyOn(Date, 'now').mockReturnValue(Date.now() + 16 * 60 * 1000);
    try {
      safeError(await request(app.getHttpServer()).patch('/matches/11/complete')
        .auth(auth.accessToken, { type: 'bearer' }), 401);
      expect(prisma.$transaction).not.toHaveBeenCalled();
    } finally { clock.mockRestore(); }
  });
  it('returns 200/409 for concurrent completion requests', async () => {
    const token = (await pair()).accessToken;
    const responses = await Promise.all([0, 1].map(() => request(app.getHttpServer())
      .patch('/matches/11/complete').auth(token, { type: 'bearer' })));
    expect(responses.map((r) => r.status).sort()).toEqual([200, 409]);
    expect(prisma.match.updateMany).toHaveBeenCalledTimes(1);
  });
  it.each([
    ['patch', '/matches/11/cancel', 10, undefined],
    ['patch', '/matches/11', 10, { endTime: '2026-12-01T12:00:00Z' }],
    ['post', '/matches/11/invite', 10, { targetUserId: 90 }],
    ['post', '/matches/11/invite', 10, { targetUserId: 60 }],
    ['post', '/matches/11/join-request', 90, undefined],
    ['post', '/open-matches/11/join', 60, undefined],
    ['patch', '/matches/11/invitations/accept', 40, undefined],
    ['patch', '/matches/11/invitations/reject', 40, undefined],
    ['patch', '/matches/11/requests/50/approve', 10, undefined],
    ['patch', '/matches/11/requests/50/reject', 10, undefined],
    ['patch', '/open-matches/11/participants/4/accept', 10, undefined],
    ['patch', '/open-matches/11/participants/4/reject', 10, undefined],
    ['patch', '/open-matches/11/leave', 30, undefined],
  ] as const)('blocks %s %s on COMPLETED Match', async (method, path, id, body) => {
    fixture.privateMatch.status = 'COMPLETED';
    const before = structuredClone(fixture.rows);
    const req = request(app.getHttpServer())[method](path).auth((await pair(id)).accessToken, { type: 'bearer' });
    const response = await (body ? req.send(body) : req);
    safeError(response, 409);
    expect(fixture.rows).toEqual(before);
    expect(prisma.match.update).not.toHaveBeenCalled();
    expect(prisma.match.updateMany).not.toHaveBeenCalled();
    expect(prisma.matchParticipant.update).not.toHaveBeenCalled();
    expect(prisma.matchParticipant.create).not.toHaveBeenCalled();
  });
});
