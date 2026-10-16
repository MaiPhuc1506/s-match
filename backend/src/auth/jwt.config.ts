import { ConfigService } from '@nestjs/config';

export const AUTH_JWT_CONFIG = Symbol('AUTH_JWT_CONFIG');

export interface AuthJwtConfig {
  accessSecret: string;
  refreshSecret: string;
  issuer: string;
  accessAudience: string;
  refreshAudience: string;
}

export function createAuthJwtConfig(config: ConfigService): AuthJwtConfig {
  const accessSecret = config.get<string>('JWT_ACCESS_SECRET');
  const refreshSecret = config.get<string>('JWT_REFRESH_SECRET');
  for (const [name, secret] of [
    ['JWT_ACCESS_SECRET', accessSecret],
    ['JWT_REFRESH_SECRET', refreshSecret],
  ] as const) {
    if (typeof secret !== 'string' || secret.trim().length < 32) {
      throw new Error(`${name} must be configured with at least 32 characters`);
    }
  }
  if (accessSecret === refreshSecret) {
    throw new Error('JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be different');
  }
  return {
    accessSecret: accessSecret!,
    refreshSecret: refreshSecret!,
    issuer: config.get<string>('JWT_ISSUER') || 's-match',
    accessAudience: 's-match-api',
    refreshAudience: 's-match-refresh',
  };
}
