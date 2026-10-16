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
import { expectSafeMatchResponse, makeMatchSecurityFixture } from '../../test/helpers/matches-security.fixture';

// Real controllers, guards, JWT verification and services; Prisma is entirely mocked.
describe('Match privacy HTTP (no PostgreSQL)', () => {
  let app: INestApplication;
  let tokens: AuthTokensService;
  let fixture: ReturnType<typeof makeMatchSecurityFixture>;
  const prisma = makeMatchSecurityFixture().prisma;
  const config: AuthJwtConfig = {
    accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
    issuer: 'match-security-test', accessAudience: 'match-api', refreshAudience: 'match-refresh',
  };
  const sessions = new Map<string, any>();

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
    fixture = makeMatchSecurityFixture();
    Object.assign(prisma, fixture.prisma);
    sessions.clear();
    prisma.refreshSession.findUnique.mockImplementation(async ({ where }: any) => sessions.get(where.id) ?? null);
  });

  async function access(id: number, role = Role.PLAYER) {
    const sid = randomUUID();
    const expiresAt = new Date(Date.now() + 60000);
    sessions.set(sid, {
      userId: id, revokedAt: null, expiresAt,
      user: { id, email: 'fixture@example.test', role: { name: role } },
    });
    return (await tokens.issuePair({ id, email: 'fixture@example.test', role }, sid, expiresAt)).accessToken;
  }

  it('allows anonymous OPEN detail with a sanitized response and no roster', async () => {
    const response = await request(app.getHttpServer()).get('/open-matches/12').expect(200);
    expect(response.body).toMatchObject({ id: 12, participantCount: 2 });
    expect(response.body).not.toHaveProperty('participants');
    expectSafeMatchResponse(response.body);
  });

  it('makes public PRIVATE and nonexistent detail indistinguishable', async () => {
    const hidden = await request(app.getHttpServer()).get('/open-matches/11').expect(404);
    const missing = await request(app.getHttpServer()).get('/open-matches/999').expect(404);
    expect(hidden.body).toEqual(missing.body);
    expect(hidden.body.message).toBe('Không tìm thấy trận đấu');
    expect(prisma.match.findUnique).not.toHaveBeenCalled();
  });

  it('does not reveal PRIVATE through a public route even with an ADMIN token', async () => {
    const token = await access(80, Role.ADMIN);
    await request(app.getHttpServer()).get('/open-matches/11').auth(token, { type: 'bearer' }).expect(404);
  });

  it.each(['/matches/11', '/matches/open'])('requires authentication at %s', async (path) => {
    await request(app.getHttpServer()).get(path).expect(401);
    expect(prisma.match.findUnique).not.toHaveBeenCalled();
    expect(prisma.match.findMany).not.toHaveBeenCalled();
  });

  it('rejects invalid, refresh-type and revoked-session tokens before Match queries', async () => {
    await request(app.getHttpServer()).get('/matches/11').auth('invalid-fixture-token', { type: 'bearer' }).expect(401);
    const sid = randomUUID();
    const expiresAt = new Date(Date.now() + 60000);
    const pair = await tokens.issuePair({ id: 10, email: 'fixture@example.test', role: Role.PLAYER }, sid, expiresAt);
    await request(app.getHttpServer()).get('/matches/11').auth(pair.refreshToken, { type: 'bearer' }).expect(401);
    sessions.set(sid, {
      userId: 10, revokedAt: new Date(), expiresAt,
      user: { id: 10, email: 'fixture@example.test', role: { name: Role.PLAYER } },
    });
    await request(app.getHttpServer()).get('/matches/11').auth(pair.accessToken, { type: 'bearer' }).expect(401);
    expect(prisma.match.findUnique).not.toHaveBeenCalled();
  });

  it.each([50, 60, 70, 90])('returns 403 for unauthorized PRIVATE reader %s', async (id) => {
    const token = await access(id);
    const response = await request(app.getHttpServer()).get('/matches/11').auth(token, { type: 'bearer' }).expect(403);
    expect(response.body.message).toBe('Bạn không có quyền xem trận đấu này');
    expect(response.body).not.toHaveProperty('participants');
    expect(response.body).not.toHaveProperty('booking');
  });

  it.each([10, 30])('allows host/ACCEPTED %s to read PRIVATE detail', async (id) => {
    const token = await access(id);
    const response = await request(app.getHttpServer()).get('/matches/11').auth(token, { type: 'bearer' }).expect(200);
    expect(response.body.participants).toHaveLength(id === 10 ? 6 : 2);
    expectSafeMatchResponse(response.body);
  });

  it('returns only an invitation preview for INVITED', async () => {
    const token = await access(40);
    const response = await request(app.getHttpServer()).get('/matches/11').auth(token, { type: 'bearer' }).expect(200);
    expect(response.body).toMatchObject({ id: 11, title: 'Private fixture', host: { id: 10 } });
    for (const key of ['participants', 'booking', 'bookingId', 'participantCount']) expect(response.body).not.toHaveProperty(key);
    expectSafeMatchResponse(response.body);
  });

  it('allows ADMIN read access without granting update/cancel rights', async () => {
    const token = await access(80, Role.ADMIN);
    const response = await request(app.getHttpServer()).get('/matches/11').auth(token, { type: 'bearer' }).expect(200);
    expectSafeMatchResponse(response.body);
    await request(app.getHttpServer()).patch('/matches/11').auth(token, { type: 'bearer' }).send({ title: 'Denied' }).expect(403);
    await request(app.getHttpServer()).patch('/matches/11/cancel').auth(token, { type: 'bearer' }).expect(403);
    expect(prisma.match.update).not.toHaveBeenCalled();
  });

  it('denies a COURT_OWNER who owns the court but has no match relationship', async () => {
    const token = await access(20, Role.OWNER);
    await request(app.getHttpServer()).get('/matches/11').auth(token, { type: 'bearer' }).expect(403);
    await request(app.getHttpServer()).patch('/matches/11').auth(token, { type: 'bearer' }).send({ title: 'Denied' }).expect(403);
    await request(app.getHttpServer()).patch('/matches/11/cancel').auth(token, { type: 'bearer' }).expect(403);
    expect(prisma.match.update).not.toHaveBeenCalled();
  });

  it.each([10, 30, 40])('uses match relationships for COURT_OWNER %s', async (id) => {
    const token = await access(id, Role.OWNER);
    await request(app.getHttpServer()).get('/matches/11').auth(token, { type: 'bearer' }).expect(200);
  });

  it.each([Role.PLAYER, Role.OWNER, Role.ADMIN])('preserves OPEN viewing for %s', async (role) => {
    const token = await access(90, role);
    const response = await request(app.getHttpServer()).get('/matches/12').auth(token, { type: 'bearer' }).expect(200);
    if (role === Role.ADMIN) expect(response.body.participants).toHaveLength(6);
    else expect(response.body).not.toHaveProperty('participants');
    expectSafeMatchResponse(response.body);
  });

  it('returns 404 for an authenticated missing match', async () => {
    const token = await access(90);
    await request(app.getHttpServer()).get('/matches/999').auth(token, { type: 'bearer' }).expect(404);
  });

  it('sanitizes all list routes without changing their OPEN/status filters', async () => {
    const publicList = await request(app.getHttpServer()).get('/open-matches').expect(200);
    const token = await access(90);
    const protectedList = await request(app.getHttpServer()).get('/matches/open').auth(token, { type: 'bearer' }).expect(200);
    for (const list of [publicList.body, protectedList.body]) {
      expect(list).toHaveLength(1);
      expect(list[0].id).toBe(12);
      expect(list[0]).not.toHaveProperty('participants');
      expectSafeMatchResponse(list[0]);
    }
    fixture.openMatch.status = 'FULL';
    const fullPublic = await request(app.getHttpServer()).get('/open-matches').expect(200);
    const fullProtected = await request(app.getHttpServer()).get('/matches/open').auth(token, { type: 'bearer' }).expect(200);
    expect(fullPublic.body).toEqual([]);
    expect(fullProtected.body).toHaveLength(1);
  });

  it('checks the current database role rather than an ADMIN claim', async () => {
    const token = await access(90, Role.ADMIN);
    for (const session of sessions.values()) session.user.role.name = Role.PLAYER;
    await request(app.getHttpServer()).get('/matches/11').auth(token, { type: 'bearer' }).expect(403);
  });

  it('leaves PRIVATE without returning inaccessible detail or changing Booking', async () => {
    const token = await access(30);
    const response = await request(app.getHttpServer()).patch('/open-matches/11/leave').auth(token, { type: 'bearer' }).expect(200);
    expect(response.body).toEqual({ id: 11, left: true });
    await request(app.getHttpServer()).get('/matches/11').auth(token, { type: 'bearer' }).expect(403);
    expect(prisma.booking.findUnique).not.toHaveBeenCalled();
  });

  it('does not expand role restrictions on PLAYER-only mutation routes', async () => {
    const token = await access(10, Role.ADMIN);
    await request(app.getHttpServer()).patch('/open-matches/11/participants/4/accept').auth(token, { type: 'bearer' }).expect(403);
    expect(prisma.matchParticipant.update).not.toHaveBeenCalled();
  });
});
