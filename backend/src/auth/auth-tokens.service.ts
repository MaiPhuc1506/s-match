import { Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import { AUTH_JWT_CONFIG, AuthJwtConfig } from './jwt.config';

export interface AuthTokenClaims {
  sub: number;
  sid: string;
  tokenType: 'access' | 'refresh';
  jti: string;
  exp: number;
  iat: number;
}

@Injectable()
export class AuthTokensService {
  constructor(
    private readonly jwt: JwtService,
    @Inject(AUTH_JWT_CONFIG) private readonly config: AuthJwtConfig,
  ) {}

  hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  matchesRefreshHash(token: string, storedHash: string): boolean {
    if (!/^[a-f0-9]{64}$/.test(storedHash)) return false;
    return timingSafeEqual(
      Buffer.from(this.hashRefreshToken(token), 'hex'),
      Buffer.from(storedHash, 'hex'),
    );
  }

  async issuePair(
    user: { id: number; email: string; role: string },
    sessionId: string,
    expiresAt: Date,
  ) {
    const refreshExpiresIn = Math.floor(expiresAt.getTime() / 1000) - Math.floor(Date.now() / 1000);
    if (refreshExpiresIn <= 0) throw new UnauthorizedException('Phiên đăng nhập đã hết hạn');
    const payload = { sub: user.id, sid: sessionId, email: user.email, role: user.role };
    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync({ ...payload, tokenType: 'access', jti: randomUUID() }, {
        secret: this.config.accessSecret,
        algorithm: 'HS256',
        issuer: this.config.issuer,
        audience: this.config.accessAudience,
        expiresIn: '15m',
      }),
      this.jwt.signAsync({ ...payload, tokenType: 'refresh', jti: randomUUID() }, {
        secret: this.config.refreshSecret,
        algorithm: 'HS256',
        issuer: this.config.issuer,
        audience: this.config.refreshAudience,
        expiresIn: refreshExpiresIn,
      }),
    ]);
    return { accessToken, refreshToken };
  }

  async verify(token: string, type: 'access' | 'refresh'): Promise<AuthTokenClaims> {
    try {
      const claims = await this.jwt.verifyAsync<AuthTokenClaims>(token, {
        secret: type === 'access' ? this.config.accessSecret : this.config.refreshSecret,
        algorithms: ['HS256'],
        issuer: this.config.issuer,
        audience: type === 'access' ? this.config.accessAudience : this.config.refreshAudience,
      });
      const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      if (
        claims.tokenType !== type || !Number.isSafeInteger(claims.sub) || claims.sub <= 0 ||
        typeof claims.sid !== 'string' || !uuid.test(claims.sid) ||
        typeof claims.jti !== 'string' || !uuid.test(claims.jti) ||
        !Number.isSafeInteger(claims.exp) || !Number.isSafeInteger(claims.iat)
      ) throw new Error('Invalid claims');
      return claims;
    } catch {
      // Never forward JWT errors containing token/configuration details.
      throw new UnauthorizedException('Token không hợp lệ hoặc đã hết hạn');
    }
  }
}
