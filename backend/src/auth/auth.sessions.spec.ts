import { ExecutionContext, ForbiddenException, Module, UnauthorizedException, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { RoleName } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { randomBytes, randomUUID } from 'node:crypto';
import { AuthService } from './auth.service';
import { AuthTokensService } from './auth-tokens.service';
import { AuthJwtConfig, createAuthJwtConfig } from './jwt.config';
import { LoginDto } from './dto/login.dto';
import { RolesGuard } from './roles.guard';
import { Role } from './roles.enum';
import { PrismaService } from '../prisma/prisma.service';
import { PrismaModule } from '../prisma/prisma.module';
import { Test } from '@nestjs/testing';
import { AuthModule } from './auth.module';

describe('Authentication sessions (Prisma mock)', () => {
  const password = randomBytes(16).toString('hex');
  const passwordHash = bcrypt.hashSync(password, 10);
  const config: AuthJwtConfig = {
    accessSecret: randomBytes(32).toString('hex'),
    refreshSecret: randomBytes(32).toString('hex'),
    issuer: 's-match-test',
    accessAudience: 's-match-api',
    refreshAudience: 's-match-refresh',
  };
  const jwt = new JwtService();
  const input = { email: 'player@example.test', password };
  type Session = {
    id: string; userId: number; refreshTokenHash: string; expiresAt: Date;
    revokedAt: Date | null; lastUsedAt: Date | null;
  };
  let sessions: Map<string, Session>;
  let user: { id: number; email: string; fullName: string; password: string; role: { name: RoleName } };
  let prisma: {
    user: { findFirst: jest.Mock };
    refreshSession: { create: jest.Mock; findUnique: jest.Mock; updateMany: jest.Mock };
  };
  let tokens: AuthTokensService;
  let service: AuthService;

  beforeEach(() => {
    sessions = new Map();
    user = { id: 7, email: input.email, fullName: 'Test Player', password: passwordHash, role: { name: RoleName.PLAYER } };
    prisma = {
      user: { findFirst: jest.fn(async () => user) },
      refreshSession: {
        create: jest.fn(async ({ data }) => {
          const session = { ...data, revokedAt: null, lastUsedAt: null };
          sessions.set(data.id, session);
          return session;
        }),
        findUnique: jest.fn(async ({ where }) => {
          const session = sessions.get(where.id);
          // Snapshot each read so concurrent calls must use the update predicate.
          return session ? { ...session, user: { ...user, role: { ...user.role } } } : null;
        }),
        updateMany: jest.fn(async ({ where, data }) => {
          let count = 0;
          for (const session of sessions.values()) {
            if (session.id !== where.id || session.userId !== where.userId || session.revokedAt !== null) continue;
            if (where.refreshTokenHash && session.refreshTokenHash !== where.refreshTokenHash) continue;
            if (where.expiresAt && session.expiresAt <= where.expiresAt.gt) continue;
            Object.assign(session, data);
            count++;
          }
          return { count };
        }),
      },
    };
    tokens = new AuthTokensService(jwt, config);
    service = new AuthService(prisma as unknown as PrismaService, tokens);
  });

  async function login() {
    const result = await service.login(input);
    const claims = await tokens.verify(result.refreshToken, 'refresh');
    return { result, claims, session: sessions.get(claims.sid)! };
  }

  function guard(requiredRoles?: Role[]) {
    const reflector = { getAllAndOverride: jest.fn(() => requiredRoles) };
    const instance = new RolesGuard(reflector as unknown as Reflector, tokens, prisma as unknown as PrismaService);
    const request: { headers: { authorization?: string }; user?: { sub: number; role: string; sid: string } } = { headers: {} };
    const context = {
      getHandler: () => () => undefined,
      getClass: () => class TestController {},
      switchToHttp: () => ({ getRequest: () => request }),
    } as unknown as ExecutionContext;
    return { instance, request, context };
  }

  it('normalizes Login before validation and persists only a refresh digest', async () => {
    const pipe = new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true });
    const dto = await pipe.transform({ ...input, email: '  PLAYER@EXAMPLE.TEST  ' }, { type: 'body', metatype: LoginDto });
    const result = await service.login(dto);
    const access = await tokens.verify(result.accessToken, 'access');
    const refresh = await tokens.verify(result.refreshToken, 'refresh');
    expect(prisma.user.findFirst).toHaveBeenCalledWith({
      where: { email: { equals: input.email, mode: 'insensitive' } }, include: { role: true },
    });
    expect(access.sid).toBe(refresh.sid);
    expect(access.sub).toBe(user.id);
    expect(access.exp - access.iat).toBe(900);
    expect(refresh.exp - refresh.iat).toBeLessThanOrEqual(604800);
    const stored = sessions.get(refresh.sid)!;
    expect(stored.refreshTokenHash).toMatch(/^[a-f0-9]{64}$/);
    expect(stored.refreshTokenHash).toBe(tokens.hashRefreshToken(result.refreshToken));
    expect(JSON.stringify(stored)).not.toContain(result.refreshToken);
    expect(Object.keys(result).sort()).toEqual(['accessToken', 'message', 'refreshToken', 'user']);
    expect(result.user).not.toHaveProperty('password');
    expect(JSON.stringify(result.user)).not.toContain(password);
    expect(JSON.stringify(result)).not.toContain(config.accessSecret);
    expect(JSON.stringify(result)).not.toContain(config.refreshSecret);
  });

  it('rejects a missing user without creating a session', async () => {
    prisma.user.findFirst.mockResolvedValue(null);
    await expect(service.login(input)).rejects.toThrow(UnauthorizedException);
    expect(prisma.refreshSession.create).not.toHaveBeenCalled();
  });

  it('rejects a wrong password without creating a session', async () => {
    await expect(service.login({ ...input, password: randomUUID() })).rejects.toThrow(UnauthorizedException);
    expect(prisma.refreshSession.create).not.toHaveBeenCalled();
  });

  it('does not return tokens if persisting the session fails', async () => {
    const failure = new Error('Database unavailable');
    prisma.refreshSession.create.mockRejectedValue(failure);
    await expect(service.login(input)).rejects.toBe(failure);
  });

  it('creates independent sessions for multiple logins', async () => {
    const first = await login();
    const second = await login();
    expect(first.claims.sid).not.toBe(second.claims.sid);
    expect(sessions.size).toBe(2);
  });

  it('rotates refresh tokens using the current database role and fixed session expiry', async () => {
    const { result, claims, session } = await login();
    const expiresAt = session.expiresAt.getTime();
    user.role.name = RoleName.COURT_OWNER;
    const pair = await service.refreshTokens(result.refreshToken);
    const next = await tokens.verify(pair.refreshToken, 'refresh');
    expect(next.sid).toBe(claims.sid);
    expect(next.jti).not.toBe(claims.jti);
    expect(jwt.decode(pair.accessToken).role).toBe(RoleName.COURT_OWNER);
    expect(session.expiresAt.getTime()).toBe(expiresAt);
    expect(session.refreshTokenHash).toBe(tokens.hashRefreshToken(pair.refreshToken));
    expect(session.lastUsedAt).toBeInstanceOf(Date);
    expect(Object.keys(pair).sort()).toEqual(['accessToken', 'refreshToken']);
    expect(prisma.refreshSession.updateMany.mock.calls[0][0].where).toMatchObject({
      id: session.id, userId: user.id, revokedAt: null, refreshTokenHash: tokens.hashRefreshToken(result.refreshToken),
    });
  });

  it('rejects reuse and commits revocation of that session only', async () => {
    const first = await login();
    const other = await login();
    const rotated = await service.refreshTokens(first.result.refreshToken);
    await expect(service.refreshTokens(first.result.refreshToken)).rejects.toThrow(UnauthorizedException);
    expect(first.session.revokedAt).toBeInstanceOf(Date);
    expect(other.session.revokedAt).toBeNull();
    await expect(service.refreshTokens(rotated.refreshToken)).rejects.toThrow(UnauthorizedException);
  });

  it.each(['expired', 'revoked', 'missing', 'wrong_owner'])('rejects a %s session', async (state) => {
    const { result, claims, session } = await login();
    if (state === 'expired') session.expiresAt = new Date(Date.now() - 1000);
    if (state === 'revoked') session.revokedAt = new Date();
    if (state === 'missing') sessions.delete(claims.sid);
    if (state === 'wrong_owner') session.userId = user.id + 1;
    await expect(service.refreshTokens(result.refreshToken)).rejects.toThrow(UnauthorizedException);
    expect(prisma.refreshSession.updateMany).not.toHaveBeenCalled();
  });

  it('revokes a session whose user has disappeared', async () => {
    const { result, session } = await login();
    prisma.refreshSession.findUnique.mockResolvedValue({ ...session, user: null });
    await expect(service.refreshTokens(result.refreshToken)).rejects.toThrow(UnauthorizedException);
    expect(session.revokedAt).toBeInstanceOf(Date);
  });

  it('never lets two concurrent refresh requests both succeed', async () => {
    const { result, session } = await login();
    const results = await Promise.allSettled([
      service.refreshTokens(result.refreshToken), service.refreshTokens(result.refreshToken),
    ]);
    expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter(r => r.status === 'rejected')).toHaveLength(1);
    // Strict replay policy: the losing request invalidates the whole session.
    expect(session.revokedAt).toBeInstanceOf(Date);
  });

  it('does not restore a session if logout races rotation', async () => {
    const { result, claims, session } = await login();
    const issuePair = tokens.issuePair.bind(tokens);
    jest.spyOn(tokens, 'issuePair').mockImplementation(async (...args) => {
      await service.logout(user.id, claims.sid);
      return issuePair(...args);
    });
    await expect(service.refreshTokens(result.refreshToken)).rejects.toThrow(UnauthorizedException);
    expect(session.revokedAt).toBeInstanceOf(Date);
  });

  it('logout revokes exactly the specified user/session and preserves its response', async () => {
    const first = await login();
    const second = await login();
    const result = await service.logout(user.id, first.claims.sid);
    expect(Object.keys(result)).toEqual(['message']);
    expect(first.session.revokedAt).toBeInstanceOf(Date);
    expect(second.session.revokedAt).toBeNull();
    expect(prisma.refreshSession.updateMany).toHaveBeenCalledWith({
      where: { id: first.claims.sid, userId: user.id, revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
  });

  it('rejects using access tokens as refresh tokens or refresh tokens as access tokens', async () => {
    const { result } = await login();
    await expect(service.refreshTokens(result.accessToken)).rejects.toThrow(UnauthorizedException);
    const g = guard();
    g.request.headers.authorization = `Bearer ${result.refreshToken}`;
    await expect(g.instance.canActivate(g.context)).rejects.toThrow(UnauthorizedException);
  });

  it('checks tokenType even for a correctly signed token', async () => {
    const token = await jwt.signAsync({ sub: user.id, sid: randomUUID(), jti: randomUUID(), tokenType: 'access' }, {
      secret: config.refreshSecret, issuer: config.issuer, audience: config.refreshAudience, expiresIn: '7d',
    });
    await expect(tokens.verify(token, 'refresh')).rejects.toThrow(UnauthorizedException);
  });

  it('rejects expired JWTs and malformed claims', async () => {
    const options = { secret: config.refreshSecret, issuer: config.issuer, audience: config.refreshAudience };
    const expired = await jwt.signAsync({ sub: user.id, sid: randomUUID(), jti: randomUUID(), tokenType: 'refresh' }, { ...options, expiresIn: -1 });
    const malformed = await jwt.signAsync({ sub: '7', sid: 'invalid', jti: randomUUID(), tokenType: 'refresh' }, { ...options, expiresIn: '7d' });
    await expect(tokens.verify(expired, 'refresh')).rejects.toThrow(UnauthorizedException);
    await expect(tokens.verify(malformed, 'refresh')).rejects.toThrow(UnauthorizedException);
  });

  it('checks the current role rather than an obsolete JWT role', async () => {
    const { result } = await login();
    user.role.name = RoleName.COURT_OWNER;
    const g = guard([Role.OWNER]);
    g.request.headers.authorization = `Bearer ${result.accessToken}`;
    await expect(g.instance.canActivate(g.context)).resolves.toBe(true);
    expect(g.request.user?.role).toBe(RoleName.COURT_OWNER);
  });

  it('returns 403 for a PLAYER at an owner-only endpoint', async () => {
    const { result } = await login();
    const g = guard([Role.OWNER]);
    g.request.headers.authorization = `Bearer ${result.accessToken}`;
    await expect(g.instance.canActivate(g.context)).rejects.toThrow(ForbiddenException);
  });

  it('rejects access immediately after logout', async () => {
    const { result, claims } = await login();
    await service.logout(user.id, claims.sid);
    const g = guard();
    g.request.headers.authorization = `Bearer ${result.accessToken}`;
    await expect(g.instance.canActivate(g.context)).rejects.toThrow(UnauthorizedException);
  });

  it('rejects missing or invalid tokens without leaking details', async () => {
    const g = guard();
    await expect(g.instance.canActivate(g.context)).rejects.toThrow(UnauthorizedException);
    const invalid = randomBytes(32).toString('hex');
    try {
      await tokens.verify(invalid, 'access');
      throw new Error('Expected rejection');
    } catch (error) {
      expect(error).toBeInstanceOf(UnauthorizedException);
      expect(JSON.stringify(error)).not.toContain(invalid);
      expect(JSON.stringify(error)).not.toContain(config.accessSecret);
      expect(JSON.stringify(error)).not.toContain(config.refreshSecret);
    }
    expect(prisma.refreshSession.findUnique).not.toHaveBeenCalled();
  });

  it('preserves database errors instead of reporting a bad token', async () => {
    const { result } = await login();
    const error = new Error('Database unavailable');
    prisma.refreshSession.findUnique.mockRejectedValue(error);
    await expect(service.refreshTokens(result.refreshToken)).rejects.toBe(error);
    const g = guard();
    g.request.headers.authorization = `Bearer ${result.accessToken}`;
    await expect(g.instance.canActivate(g.context)).rejects.toBe(error);
  });

  it('injects the authentication guard into another module without a database connection', async () => {
    @Module({ providers: [RolesGuard] })
    class ConsumerModule {}
    const values: Record<string, string> = {
      JWT_ACCESS_SECRET: config.accessSecret,
      JWT_REFRESH_SECRET: config.refreshSecret,
      JWT_ISSUER: config.issuer,
    };
    const module = await Test.createTestingModule({
      imports: [AuthModule, PrismaModule, ConsumerModule],
    })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(ConfigService).useValue({ get: (key: string) => values[key] })
      .compile();
    expect(module.get(RolesGuard)).toBeInstanceOf(RolesGuard);
    await module.close();
    expect(prisma.refreshSession.create).not.toHaveBeenCalled();
  });
});

describe('JWT configuration', () => {
  // Isolate validation from process.env loaded by other suites.
  const configFrom = (values: Record<string, string | undefined>) =>
    ({ get: (key: string) => values[key] }) as ConfigService;
  it.each(['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'])('fails clearly when %s is missing', (missing) => {
    const cfg = configFrom({
      JWT_ACCESS_SECRET: missing === 'JWT_ACCESS_SECRET' ? undefined : randomBytes(32).toString('hex'),
      JWT_REFRESH_SECRET: missing === 'JWT_REFRESH_SECRET' ? undefined : randomBytes(32).toString('hex'),
    });
    expect(() => createAuthJwtConfig(cfg)).toThrow(missing);
  });

  it('rejects equal secrets without including their value in the error', () => {
    const secret = randomBytes(32).toString('hex');
    try {
      createAuthJwtConfig(configFrom({ JWT_ACCESS_SECRET: secret, JWT_REFRESH_SECRET: secret }));
      throw new Error('Expected rejection');
    } catch (error) {
      expect((error as Error).message).not.toContain(secret);
      expect((error as Error).message).toContain('must be different');
    }
  });
});
