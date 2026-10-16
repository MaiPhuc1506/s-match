import { INestApplication } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { AuthModule } from '../auth/auth.module';
import { AuthTokensService } from '../auth/auth-tokens.service';
import { AUTH_JWT_CONFIG, AuthJwtConfig } from '../auth/jwt.config';
import { Role } from '../auth/roles.enum';
import { PrismaModule } from '../prisma/prisma.module';
import { PrismaService } from '../prisma/prisma.service';
import { UsersModule } from './users.module';

// Real HTTP routing, JWT verification and RolesGuard; all persistence is mocked.
describe('Users HTTP authorization (no database)', () => {
  const config: AuthJwtConfig = {
    accessSecret: randomBytes(32).toString('hex'),
    refreshSecret: randomBytes(32).toString('hex'),
    issuer: 'users-test',
    accessAudience: 'users-api',
    refreshAudience: 'users-refresh',
  };
  const sid = randomUUID();
  const record = { id: 8, fullName: 'Test Player', role: { name: Role.PLAYER } };
  const prisma = {
    user: { findMany: jest.fn(), findUnique: jest.fn() },
    refreshSession: { findUnique: jest.fn() },
  };
  let app: INestApplication;
  let tokens: AuthTokensService;
  let session: {
    userId: number; revokedAt: Date | null; expiresAt: Date;
    user: { id: number; email: string; role: { name: Role } };
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [PrismaModule, AuthModule, UsersModule],
    })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(AUTH_JWT_CONFIG).useValue(config)
      .compile();
    tokens = module.get(AuthTokensService);
    app = module.createNestApplication();
    await app.init();
  });

  afterAll(async () => { await app?.close(); });

  beforeEach(() => {
    jest.resetAllMocks();
    session = {
      userId: 8, revokedAt: null, expiresAt: new Date(Date.now() + 60_000),
      user: { id: 8, email: 'test@example.test', role: { name: Role.PLAYER } },
    };
    prisma.refreshSession.findUnique.mockImplementation(async ({ where }) => where.id === sid ? session : null);
    prisma.user.findMany.mockResolvedValue([record]);
    prisma.user.findUnique.mockImplementation(async ({ where }) => where.id === 8 ? record : null);
  });

  async function pair(role = Role.PLAYER) {
    session.user.role.name = role;
    return tokens.issuePair({ id: 8, email: session.user.email, role }, sid, session.expiresAt);
  }

  it.each(['/users', '/users/', '/users/8'])('returns 401 without a token at %s', async (path) => {
    await request(app.getHttpServer()).get(path).expect(401);
    expect(prisma.user.findMany).not.toHaveBeenCalled();
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it.each([Role.PLAYER, Role.OWNER])('returns 403 for %s listing users', async (role) => {
    const { accessToken } = await pair(role);
    await request(app.getHttpServer()).get('/users').auth(accessToken, { type: 'bearer' }).expect(403);
    expect(prisma.user.findMany).not.toHaveBeenCalled();
  });

  it('returns an array with only approved fields for ADMIN', async () => {
    const { accessToken } = await pair(Role.ADMIN);
    const response = await request(app.getHttpServer()).get('/users/').auth(accessToken, { type: 'bearer' }).expect(200);
    expect(response.body).toEqual([record]);
    expect(Object.keys(response.body[0]).sort()).toEqual(['fullName', 'id', 'role']);
    expect(Object.keys(response.body[0].role)).toEqual(['name']);
  });

  it.each([Role.PLAYER, Role.OWNER, Role.ADMIN])('allows %s self access with the minimal object response', async (role) => {
    const { accessToken } = await pair(role);
    const response = await request(app.getHttpServer()).get('/users/8').auth(accessToken, { type: 'bearer' }).expect(200);
    expect(response.body).toEqual(record);
    expect(Object.keys(response.body).sort()).toEqual(['fullName', 'id', 'role']);
    expect(Object.keys(response.body.role)).toEqual(['name']);
  });

  it.each([Role.PLAYER, Role.OWNER])('blocks %s cross-user access for existing and missing IDs without querying them', async (role) => {
    const { accessToken } = await pair(role);
    prisma.user.findUnique.mockResolvedValue(record);
    await request(app.getHttpServer()).get('/users/9').auth(accessToken, { type: 'bearer' }).expect(403);
    prisma.user.findUnique.mockResolvedValue(null);
    await request(app.getHttpServer()).get('/users/999').auth(accessToken, { type: 'bearer' }).expect(403);
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it('allows ADMIN cross-user access and returns 404 for a missing ID', async () => {
    const { accessToken } = await pair(Role.ADMIN);
    prisma.user.findUnique.mockResolvedValueOnce({ ...record, id: 9 });
    await request(app.getHttpServer()).get('/users/9').auth(accessToken, { type: 'bearer' }).expect(200);
    await request(app.getHttpServer()).get('/users/999').auth(accessToken, { type: 'bearer' }).expect(404);
  });

  it.each([Role.PLAYER, Role.OWNER, Role.ADMIN])('returns 400 for an invalid ID with authenticated %s', async (role) => {
    const { accessToken } = await pair(role);
    await request(app.getHttpServer()).get('/users/not-an-id').auth(accessToken, { type: 'bearer' }).expect(400);
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it.each(['0', '-1', '1.5', '2147483648', '9007199254740993', '1e3', 'NaN', 'Infinity'])(
    'returns 400 for ID %s for every authenticated role before querying the target', async (id) => {
      for (const role of [Role.PLAYER, Role.OWNER, Role.ADMIN]) {
        const { accessToken } = await pair(role);
        await request(app.getHttpServer()).get(`/users/${id}`).auth(accessToken, { type: 'bearer' }).expect(400);
      }
      expect(prisma.user.findUnique).not.toHaveBeenCalled();
    },
  );

  it.each([1, 2147483647])('accepts boundary %s and preserves 403/404 authorization semantics', async (id) => {
    for (const role of [Role.PLAYER, Role.OWNER]) {
      const { accessToken } = await pair(role);
      await request(app.getHttpServer()).get(`/users/${id}`).auth(accessToken, { type: 'bearer' }).expect(403);
    }
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
    const { accessToken } = await pair(Role.ADMIN);
    await request(app.getHttpServer()).get(`/users/${id}`).auth(accessToken, { type: 'bearer' }).expect(404);
    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { id }, select: { id: true, fullName: true, role: { select: { name: true } } },
    });
  });

  it('keeps 401 precedence over ID validation when unauthenticated', async () => {
    await request(app.getHttpServer()).get('/users/0').expect(401);
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it('rejects a refresh token used as an access token', async () => {
    const { refreshToken } = await pair();
    await request(app.getHttpServer()).get('/users/8').auth(refreshToken, { type: 'bearer' }).expect(401);
    expect(prisma.refreshSession.findUnique).not.toHaveBeenCalled();
  });

  it('rejects expired access tokens', async () => {
    const token = await new JwtService().signAsync({ sub: 8, sid, tokenType: 'access', jti: randomUUID() }, {
      secret: config.accessSecret, algorithm: 'HS256', issuer: config.issuer,
      audience: config.accessAudience, expiresIn: -1,
    });
    await request(app.getHttpServer()).get('/users/8').auth(token, { type: 'bearer' }).expect(401);
    expect(prisma.refreshSession.findUnique).not.toHaveBeenCalled();
  });

  it('rejects invalid tokens', async () => {
    await request(app.getHttpServer()).get('/users/8').auth('invalid-test-token', { type: 'bearer' }).expect(401);
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it('rejects a revoked session before querying the user endpoint', async () => {
    const { accessToken } = await pair();
    session.revokedAt = new Date();
    await request(app.getHttpServer()).get('/users/8').auth(accessToken, { type: 'bearer' }).expect(401);
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it('uses the database role rather than the role claimed in the JWT', async () => {
    const { accessToken } = await pair(Role.ADMIN);
    session.user.role.name = Role.PLAYER;
    await request(app.getHttpServer()).get('/users').auth(accessToken, { type: 'bearer' }).expect(403);
    await request(app.getHttpServer()).get('/users/9').auth(accessToken, { type: 'bearer' }).expect(403);
    expect(prisma.user.findMany).not.toHaveBeenCalled();
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });
});
