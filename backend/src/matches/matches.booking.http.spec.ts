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
import { makeMatchBookingFixture, bookingUniqueError } from '../../test/helpers/matches-booking.fixture';
import { expectSafeMatchResponse } from '../../test/helpers/matches-security.fixture';

describe('Match Booking ownership HTTP (no PostgreSQL)', () => {
  const prisma = makeMatchBookingFixture().prisma;
  let fixture: ReturnType<typeof makeMatchBookingFixture>;
  let app: INestApplication;
  let tokens: AuthTokensService;
  const config: AuthJwtConfig = {
    accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
    issuer: 'booking-ownership-test', accessAudience: 'match-api', refreshAudience: 'match-refresh',
  };
  const sessions = new Map<string, any>();
  const create = { title: 'Fixture', startTime: '2026-10-20T18:00:00Z', endTime: '2026-10-20T19:00:00Z' };
  const open = { mode: 'DOUBLES', purpose: 'CASUAL', neededPlayers: 2, minSkillLevel: 1, maxSkillLevel: 5 };

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [PrismaModule, AuthModule, MatchesModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(AUTH_JWT_CONFIG).useValue(config)
      .compile();
    tokens = module.get(AuthTokensService);
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    await app.init();
  });
  afterAll(async () => { await app?.close(); });
  beforeEach(() => {
    fixture = makeMatchBookingFixture();
    Object.assign(prisma, fixture.prisma);
    sessions.clear();
    prisma.refreshSession.findUnique.mockImplementation(async ({ where }: any) => sessions.get(where.id) ?? null);
  });
  async function token(id = 10, role = Role.PLAYER) {
    const sid = randomUUID();
    const expiresAt = new Date(Date.now() + 60000);
    sessions.set(sid, { userId: id, revokedAt: null, expiresAt, user: { id, email: 'fixture@example.test', role: { name: role } } });
    return (await tokens.issuePair({ id, email: 'fixture@example.test', role }, sid, expiresAt)).accessToken;
  }
  function attach(path: string, auth: string, bookingId: any) {
    const http = request(app.getHttpServer());
    if (path === 'create') return http.post('/matches').auth(auth, { type: 'bearer' }).send({ ...create, bookingId });
    if (path === 'patch') return http.patch('/matches/11').auth(auth, { type: 'bearer' }).send({ bookingId });
    return http.post(`/bookings/${bookingId}/open-match`).auth(auth, { type: 'bearer' }).send(open);
  }
  function noWrites() {
    expect(prisma.match.create).not.toHaveBeenCalled();
    expect(prisma.match.update).not.toHaveBeenCalled();
    expect(prisma.matchParticipant.create).not.toHaveBeenCalled();
    expect(prisma.matchParticipant.update).not.toHaveBeenCalled();
  }
  function safeError(body: any, status: number) {
    expect(body.statusCode).toBe(status);
    expect(Object.keys(body).sort()).toEqual(['error', 'message', 'statusCode']);
    expect(JSON.stringify(body)).not.toMatch(/PRIVATE_|bookingId_key|Prisma|userId|@example/);
  }

  it.each(['create', 'patch', 'open'])('attaches an owned CONFIRMED Booking via %s', async (path) => {
    const response = await attach(path, await token(), 102).expect(path === 'patch' ? 200 : 201);
    expectSafeMatchResponse(response.body);
    expect(fixture.rows.some((row) => row.bookingId === 102 && row.hostId === 10)).toBe(true);
  });

  it.each(['create', 'patch', 'open'])('returns 403 for another user Booking without mutation via %s', async (path) => {
    const before = JSON.stringify(fixture.rows);
    const response = await attach(path, await token(), 103).expect(403);
    safeError(response.body, 403);
    expect(JSON.stringify(fixture.rows)).toBe(before);
    noWrites();
  });

  it.each(['create', 'patch', 'open'])('rejects PENDING/CANCELLED/COMPLETED with 409 via %s', async (path) => {
    const auth = await token();
    for (const bookingId of [104, 105, 106]) {
      const response = await attach(path, auth, bookingId).expect(409);
      safeError(response.body, 409);
      noWrites();
    }
  });

  it.each(['create', 'patch', 'open'])('returns 409 for a Booking attached to another Match via %s', async (path) => {
    fixture.bookings.get(101).userId = 10;
    const response = await attach(path, await token(), 101).expect(409);
    safeError(response.body, 409);
    noWrites();
  });

  it.each(['create', 'patch', 'open'])('returns generic 404 for a nonexistent Booking via %s', async (path) => {
    const response = await attach(path, await token(), 999).expect(404);
    safeError(response.body, 404);
    expect(response.body.message).toBe('Không tìm thấy đơn đặt sân');
    noWrites();
  });

  it.each(['create', 'patch', 'open'])('returns 400 for invalid bookingId via %s', async (path) => {
    const auth = await token();
    const ids = path === 'open' ? [0, -1, 1.5, 2147483648, 'abc'] : [null, 0, -1, 1.5, 2147483648, '102'];
    for (const id of ids) {
      await attach(path, auth, id).expect(400);
      noWrites();
    }
    expect(prisma.booking.findUnique).not.toHaveBeenCalled();
  });

  it.each([Role.OWNER, Role.ADMIN])('does not let %s bypass ownership on create or PATCH', async (role) => {
    const id = role === Role.ADMIN ? 80 : 20;
    const auth = await token(id, role);
    await attach('create', auth, 102).expect(403);
    // Now this caller is the stored host, but still cannot borrow user 10's Booking.
    fixture.privateMatch.hostId = id;
    await attach('patch', auth, 102).expect(403);
    noWrites();
  });

  it.each([{ id: 20, role: Role.OWNER, bookingId: 103 }, { id: 80, role: Role.ADMIN, bookingId: 108 }])(
    'preserves existing create permissions for $role with its own Booking', async ({ id, role, bookingId }) => {
      const response = await attach('create', await token(id, role), bookingId).expect(201);
      expect(response.body.hostId).toBe(id);
      expectSafeMatchResponse(response.body);
    },
  );

  it('rejects ADMIN non-host PATCH before reading Booking', async () => {
    await attach('patch', await token(80, Role.ADMIN), 108).expect(403);
    expect(prisma.booking.findUnique).not.toHaveBeenCalled();
    noWrites();
  });

  it('returns 404 for missing Match before reading Booking', async () => {
    const auth = await token();
    await request(app.getHttpServer()).patch('/matches/999').auth(auth, { type: 'bearer' }).send({ bookingId: 102 }).expect(404);
    expect(prisma.booking.findUnique).not.toHaveBeenCalled();
    noWrites();
  });

  it('does not allow client-supplied hostId or userId', async () => {
    const auth = await token();
    for (const identity of [{ hostId: 20 }, { userId: 20 }]) {
      await request(app.getHttpServer()).post('/matches').auth(auth, { type: 'bearer' }).send({ ...create, bookingId: 103, ...identity }).expect(400);
      await request(app.getHttpServer()).patch('/matches/11').auth(auth, { type: 'bearer' }).send({ bookingId: 103, ...identity }).expect(400);
    }
    noWrites();
  });

  it('keeps the link when PATCH omits bookingId', async () => {
    const auth = await token();
    await request(app.getHttpServer()).patch('/matches/11').auth(auth, { type: 'bearer' }).send({ title: 'Changed' }).expect(200);
    expect(fixture.privateMatch.bookingId).toBe(100);
    expect(prisma.booking.findUnique).not.toHaveBeenCalled();
    expect(prisma.match.update.mock.calls[0][0].data).not.toHaveProperty('bookingId');
  });

  it('accepts the current valid bookingId without rewriting the relation', async () => {
    await attach('patch', await token(), 100).expect(200);
    expect(fixture.privateMatch.bookingId).toBe(100);
    for (const [args] of prisma.match.update.mock.calls) expect(args.data).not.toHaveProperty('bookingId');
  });

  it('rejects PATCH null and preserves all data', async () => {
    const before = JSON.stringify(fixture.rows);
    await attach('patch', await token(), null).expect(400);
    expect(JSON.stringify(fixture.rows)).toBe(before);
    noWrites();
  });

  it.each(['create', 'patch', 'open'])('sanitizes unique race errors as 409 via %s', async (path) => {
    const write = path === 'patch' ? prisma.match.update : prisma.match.create;
    write.mockRejectedValueOnce(bookingUniqueError());
    const before = JSON.stringify(fixture.rows);
    const response = await attach(path, await token(), 102).expect(409);
    safeError(response.body, 409);
    expect(JSON.stringify(fixture.rows)).toBe(before);
  });

  it.each(['create', 'patch', 'mixed'])('maps concurrent unique competition to one success and one 409: %s', async (kind) => {
    const auth = await token();
    const count = fixture.rows.length;
    let second: any;
    if (kind === 'patch') {
      fixture.openMatch.hostId = 10;
      fixture.bookings.get(101).userId = 10;
      second = request(app.getHttpServer()).patch('/matches/12').auth(auth, { type: 'bearer' }).send({ bookingId: 102 });
    } else second = attach(kind === 'mixed' ? 'open' : 'create', auth, 102);
    const responses = await Promise.all([attach(kind === 'patch' ? 'patch' : 'create', auth, 102), second]);
    expect(responses.map((r) => r.status).sort((a, b) => a - b)).toEqual([kind === 'patch' ? 200 : 201, 409]);
    expect(fixture.rows.filter((row) => row.bookingId === 102)).toHaveLength(1);
    expect(fixture.rows).toHaveLength(count + (kind === 'patch' ? 0 : 1));
  });

  it('keeps anonymous requests and refresh tokens blocked before attachment checks', async () => {
    await request(app.getHttpServer()).post('/matches').send({ ...create, bookingId: 102 }).expect(401);
    const pair = await tokens.issuePair({ id: 10, email: 'fixture@example.test', role: Role.PLAYER }, randomUUID(), new Date(Date.now() + 60000));
    await attach('create', pair.refreshToken, 102).expect(401);
    expect(prisma.booking.findUnique).not.toHaveBeenCalled();
    noWrites();
  });
});
