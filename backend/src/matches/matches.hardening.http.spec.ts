import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { AuthModule } from '../auth/auth.module';
import { AuthTokensService } from '../auth/auth-tokens.service';
import { AUTH_JWT_CONFIG, AuthJwtConfig } from '../auth/jwt.config';
import { Role } from '../auth/roles.enum';
import { PrismaModule } from '../prisma/prisma.module';
import { PrismaService } from '../prisma/prisma.service';
import { MatchesModule } from './matches.module';
import { makeMatchBookingFixture } from '../../test/helpers/matches-booking.fixture';
import { expectSafeMatchResponse } from '../../test/helpers/matches-security.fixture';

describe('Match hardening 2D HTTP (Prisma mock only)', () => {
  const prisma = makeMatchBookingFixture().prisma;
  let fixture: ReturnType<typeof makeMatchBookingFixture>;
  let app: INestApplication;
  let tokens: AuthTokensService;
  const config: AuthJwtConfig = {
    accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
    issuer: 'match-hardening-test', accessAudience: 'match-api', refreshAudience: 'match-refresh',
  };
  const sessions = new Map<string, any>();
  const create = { title: 'Fixture', startTime: '2026-10-20T18:00:00Z', endTime: '2026-10-20T19:00:00Z' };
  const open = { mode: 'DOUBLES', purpose: 'CASUAL', neededPlayers: 2, minSkillLevel: 1, maxSkillLevel: 5 };
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [PrismaModule, AuthModule, MatchesModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(AUTH_JWT_CONFIG).useValue(config).compile();
    tokens = module.get(AuthTokensService);
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
    await app.init();
  });
  afterAll(async () => { await app?.close(); });
  beforeEach(() => {
    fixture = makeMatchBookingFixture();
    Object.assign(prisma, fixture.prisma);
    sessions.clear();
    prisma.refreshSession.findUnique.mockImplementation(async ({ where }: any) => sessions.get(where.id) ?? null);
  });
  async function token(id: number) {
    const sid = randomUUID();
    const expiresAt = new Date(Date.now() + 60000);
    sessions.set(sid, { userId: id, revokedAt: null, expiresAt, user: { id, email: 'fixture@example.test', role: { name: Role.PLAYER } } });
    return (await tokens.issuePair({ id, email: 'fixture@example.test', role: Role.PLAYER }, sid, expiresAt)).accessToken;
  }
  async function send(method: 'post' | 'patch', path: string, userId: number, body = {}) {
    return request(app.getHttpServer())[method](path).auth(await token(userId), { type: 'bearer' }).send(body);
  }
  function noWrites() {
    for (const model of [prisma.match, prisma.matchParticipant]) {
      expect(model.create).not.toHaveBeenCalled();
      expect(model.update).not.toHaveBeenCalled();
    }
  }
  const actions = [
    ['post', '/matches/11/invite', 10, { targetUserId: 90 }, 201],
    ['post', '/matches/11/invite', 10, { targetUserId: 60 }, 201],
    ['post', '/matches/12/join-request', 90, {}, 201],
    ['post', '/matches/12/join-request', 60, {}, 201],
    ['post', '/open-matches/12/join', 90, {}, 201],
    ['post', '/open-matches/12/join', 60, {}, 201],
    ['patch', '/matches/11/invitations/accept', 40, {}, 200],
    ['patch', '/matches/11/invitations/reject', 40, {}, 200],
    ['patch', '/matches/11/requests/50/approve', 10, {}, 200],
    ['patch', '/matches/11/requests/50/reject', 10, {}, 200],
    ['patch', '/open-matches/11/participants/4/accept', 10, {}, 200],
    ['patch', '/open-matches/11/participants/4/reject', 10, {}, 200],
  ] as const;
  it.each(actions)('%s %s user %s returns exactly five fields', async (method, path, id, body, status) => {
    const response = await send(method, path, id, body);
    expect(response.status).toBe(status);
    expect(Object.keys(response.body).sort()).toEqual(['id', 'matchId', 'role', 'status', 'userId']);
    expect(response.body.matchId).toBe(Number(path.split('/')[2]));
    expect(Number.isInteger(response.body.id)).toBe(true);
    expect(Number.isInteger(response.body.userId)).toBe(true);
    expect(['HOST', 'MEMBER']).toContain(response.body.role);
    expect(['INVITED', 'REQUESTED', 'ACCEPTED', 'REJECTED']).toContain(response.body.status);
    expectSafeMatchResponse(response.body);
  });
  it('keeps leave acknowledgement unchanged', async () => {
    const response = await send('patch', '/open-matches/11/leave', 30);
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ id: 11, left: true });
  });

  const acceptance = [
    ['/matches/11/invitations/accept', 40],
    ['/matches/11/requests/50/approve', 10],
    ['/open-matches/11/participants/4/accept', 10],
  ] as const;
  for (const status of ['OPEN', 'FULL', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']) {
    it.each(acceptance)('acceptance endpoint %s user %s with Match ' + status, async (path, id) => {
      fixture.privateMatch.status = status;
      const before = JSON.stringify(fixture.rows);
      const response = await send('patch', path, id);
      expect(response.status).toBe(status === 'OPEN' ? 200 : 409);
      if (status !== 'OPEN') {
        noWrites();
        expect(JSON.stringify(fixture.rows)).toBe(before);
      }
    });
  }
  it.each(acceptance)('keeps 400 for OPEN but full at %s', async (path, id) => {
    fixture.privateMatch.maxPlayers = 2;
    expect((await send('patch', path, id)).status).toBe(400);
    noWrites();
  });
  it.each(acceptance)('keeps pending status validation at %s', async (path, id) => {
    fixture.privateMatch.participants[path.includes('invitations') ? 2 : 3].status = 'REJECTED';
    expect((await send('patch', path, id)).status).toBe(400);
    noWrites();
  });
  it('preserves host-only authorization', async () => {
    fixture.privateMatch.status = 'CANCELLED';
    expect((await send('patch', '/matches/11/requests/50/approve', 90)).status).toBe(403);
    noWrites();
  });

  it.each([
    { startTime: 'invalid' }, { endTime: 'invalid' }, { startTime: null }, { endTime: null },
    { startTime: create.endTime }, { endTime: create.startTime },
    { startTime: '2026-10-20T20:00:00Z' }, { endTime: '2026-10-20T17:00:00Z' },
    { startTime: '2026-10-21T20:00:00Z', endTime: '2026-10-21T19:00:00Z' },
    { startTime: '2026-10-21T19:00:00Z', endTime: '2026-10-21T19:00:00Z' },
  ])('rejects invalid final PATCH pair before mutation: %j', async (body) => {
    const before = JSON.stringify(fixture.rows);
    expect((await send('patch', '/matches/11', 10, { ...body, bookingId: 102 })).status).toBe(400);
    noWrites();
    expect(JSON.stringify(fixture.rows)).toBe(before);
  });
  it.each([
    { startTime: 'invalid' }, { endTime: 'invalid' }, { startTime: null }, { endTime: null },
    { startTime: create.endTime }, { endTime: create.startTime },
    { startTime: '2026-10-20T20:00:00Z' },
  ])('rejects invalid create times: %j', async (body) => {
    expect((await send('post', '/matches', 10, { ...create, ...body })).status).toBe(400);
    noWrites();
  });
  it.each([
    { startTime: '2026-10-20T18:30:00Z' }, { endTime: '2026-10-20T19:30:00Z' },
    { startTime: '2026-10-21T18:00:00Z', endTime: '2026-10-21T19:00:00Z' },
    { startTime: '2026-10-20T20:00:00+02:00', endTime: '2026-10-20T18:30:00Z' },
  ])('accepts valid merged times without writing omitted fields: %j', async (body) => {
    const response = await send('patch', '/matches/11', 10, body);
    expect(response.status).toBe(200);
    expect(Object.keys(prisma.match.update.mock.calls[0][0].data).sort()).toEqual(Object.keys(body).sort());
    expectSafeMatchResponse(response.body);
  });
  it('supports timezone offsets and historical dates on create', async () => {
    const response = await send('post', '/matches', 10, { ...create, startTime: '2020-01-01T12:00:00+02:00', endTime: '2020-01-01T10:30:00Z' });
    expect(response.status).toBe(201);
    expect(response.body.startTime).toBe('2020-01-01T10:00:00.000Z');
  });
  it('allows title-only PATCH without validating legacy times', async () => {
    fixture.privateMatch.endTime = new Date('2020-01-01');
    expect((await send('patch', '/matches/11', 10, { title: 'Changed' })).status).toBe(200);
    expect(prisma.match.update.mock.calls[0][0].data).toEqual({ title: 'Changed' });
  });

  it.each([null, 0, 1, 2.5, '4', 2147483648])('rejects POST/PATCH maxPlayers=%j without mutation', async (maxPlayers) => {
    expect((await send('post', '/matches', 10, { ...create, maxPlayers })).status).toBe(400);
    expect((await send('patch', '/matches/11', 10, { maxPlayers })).status).toBe(400);
    noWrites();
  });
  it.each([2, 2147483647])('accepts POST/PATCH maxPlayers boundary %s', async (maxPlayers) => {
    expect((await send('post', '/matches', 10, { ...create, maxPlayers })).status).toBe(201);
    expect((await send('patch', '/matches/11', 10, { maxPlayers })).status).toBe(200);
    expect(fixture.privateMatch.maxPlayers).toBe(maxPlayers);
  });
  it('retains OPEN/4/0 POST defaults', async () => {
    const response = await send('post', '/matches', 10, create);
    expect(response.status).toBe(201);
    expect(response.body).toMatchObject({ privacy: 'OPEN', maxPlayers: 4, feePerPlayer: 0 });
  });
  it.each([null, 0, 1.5, 2147483647, '2'])('rejects neededPlayers=%j before overflow', async (neededPlayers) => {
    expect((await send('post', '/bookings/102/open-match', 10, { ...open, neededPlayers })).status).toBe(400);
    noWrites();
  });
  it.each([1, 2147483646])('accepts neededPlayers=%s within PostgreSQL Int', async (neededPlayers) => {
    const response = await send('post', '/bookings/102/open-match', 10, { ...open, neededPlayers });
    expect(response.status).toBe(201);
    expect(response.body.maxPlayers).toBe(neededPlayers + 1);
    expectSafeMatchResponse(response.body);
  });
});
