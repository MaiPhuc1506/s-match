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

describe('PATCH Match defaults HTTP regression (Prisma mock)', () => {
  const prisma = makeMatchBookingFixture().prisma;
  let fixture: ReturnType<typeof makeMatchBookingFixture>;
  let app: INestApplication;
  let tokens: AuthTokensService;
  const config: AuthJwtConfig = {
    accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
    issuer: 'patch-defaults-test', accessAudience: 'match-api', refreshAudience: 'match-refresh',
  };
  const sessions = new Map<string, any>();
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
    Object.assign(fixture.privateMatch, { maxPlayers: 8, feePerPlayer: 75000 });
    Object.assign(prisma, fixture.prisma);
    sessions.clear();
    prisma.refreshSession.findUnique.mockImplementation(async ({ where }: any) => sessions.get(where.id) ?? null);
  });
  async function token(id = 10) {
    const sid = randomUUID();
    const expiresAt = new Date(Date.now() + 60000);
    sessions.set(sid, { userId: id, revokedAt: null, expiresAt, user: { id, email: 'fixture@example.test', role: { name: Role.PLAYER } } });
    return (await tokens.issuePair({ id, email: 'fixture@example.test', role: Role.PLAYER }, sid, expiresAt)).accessToken;
  }
  async function patch(body: object) {
    return request(app.getHttpServer()).patch('/matches/11').auth(await token(), { type: 'bearer' }).send(body);
  }

  it('title-only PATCH retains PRIVATE and all omitted fields with safe projection', async () => {
    const before = { ...fixture.privateMatch };
    const response = await patch({ title: 'Changed' });
    expect(response.status).toBe(200);
    expect(fixture.privateMatch).toEqual({ ...before, title: 'Changed' });
    expect(prisma.match.update.mock.calls[0][0].data).toEqual({ title: 'Changed' });
    expectSafeMatchResponse(response.body);
    expect(response.body).toMatchObject({ privacy: 'PRIVATE', maxPlayers: 8, feePerPlayer: 75000 });
    await request(app.getHttpServer()).get('/matches/11').auth(await token(90), { type: 'bearer' }).expect(403);
  });

  it('current Booking alone is a validated no-op and retains scalar values', async () => {
    const before = JSON.stringify(fixture.rows);
    const response = await patch({ bookingId: 100 });
    expect(response.status).toBe(200);
    expect(JSON.stringify(fixture.rows)).toBe(before);
    expect(prisma.match.update).not.toHaveBeenCalled();
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expectSafeMatchResponse(response.body);
  });

  it.each([{ privacy: 'OPEN' }, { privacy: 'PRIVATE' }, { feePerPlayer: 0 }, { maxPlayers: 6 }])('updates explicitly supplied values: %j', async (body) => {
    if (body.privacy === 'PRIVATE') fixture.privateMatch.privacy = 'OPEN';
    const response = await patch(body);
    expect(response.status).toBe(200);
    expect(prisma.match.update.mock.calls[0][0].data).toEqual(body);
    expect(response.body).toMatchObject(body);
    expectSafeMatchResponse(response.body);
  });

  it('explicit nullable scalars remain deliberate clearing operations', async () => {
    const body = { description: null, location: null, feePerPlayer: null };
    const response = await patch(body);
    expect(response.status).toBe(200);
    expect(response.body).toMatchObject(body);
    expect(prisma.match.update.mock.calls[0][0].data).toEqual(body);
  });

  it.each([
    { privacy: null }, { privacy: 'INVALID' }, { maxPlayers: null }, { maxPlayers: 1 },
    { maxPlayers: 2.5 }, { maxPlayers: '8' }, { feePerPlayer: '0' }, { title: null },
    { title: '' }, { startTime: 'invalid' }, { startTime: null }, { endTime: null },
    { bookingId: null }, { hostId: 20 }, { userId: 20 },
    { booking: { connect: { id: 103 } } }, { participants: { deleteMany: {} } }, { status: 'CANCELLED' },
  ])('returns 400 without mutation for %j', async (body) => {
    const before = JSON.stringify(fixture.rows);
    const response = await patch(body);
    expect(response.status).toBe(400);
    expect(prisma.match.update).not.toHaveBeenCalled();
    expect(JSON.stringify(fixture.rows)).toBe(before);
  });

  it('keeps Booking ownership and transaction checks when changing the link', async () => {
    const before = JSON.stringify(fixture.rows);
    expect((await patch({ title: 'Changed', bookingId: 103 })).status).toBe(403);
    expect(prisma.match.update).not.toHaveBeenCalled();
    expect(JSON.stringify(fixture.rows)).toBe(before);
    const response = await patch({ bookingId: 102 });
    expect(response.status).toBe(200);
    expect(prisma.match.update.mock.calls[0][0].data).toEqual({ bookingId: 102 });
    expect(response.body).toMatchObject({ privacy: 'PRIVATE', maxPlayers: 8, feePerPlayer: 75000 });
    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    expectSafeMatchResponse(response.body);
  });

  it('POST retains OPEN/4/0 defaults through the real ValidationPipe', async () => {
    const response = await request(app.getHttpServer()).post('/matches').auth(await token(), { type: 'bearer' })
      .send({ title: 'Create', startTime: '2026-10-21T18:00:00Z', endTime: '2026-10-21T20:00:00Z' }).expect(201);
    expect(response.body).toMatchObject({ privacy: 'OPEN', maxPlayers: 4, feePerPlayer: 0 });
    expectSafeMatchResponse(response.body);
  });
});
