import { ConflictException, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { OAuth2Client } from 'google-auth-library';
import { AuthService } from './auth.service';

describe('Google auth (mock provider and Prisma)', () => {
  const oldAudience = process.env.GOOGLE_SERVER_CLIENT_ID;
  const identity = { sub: 'subject-1', email: 'player@example.com', email_verified: true, name: 'Google Player' };
  const user = { id: 7, email: identity.email, fullName: 'Existing name', role: { name: 'PLAYER' } };
  let verify: jest.SpyInstance;
  let service: AuthService;
  let db: any;

  beforeEach(() => {
    process.env.GOOGLE_SERVER_CLIENT_ID = 'test-audience';
    verify = jest.spyOn(OAuth2Client.prototype, 'verifyIdToken');
    verify.mockResolvedValue({ getPayload: () => identity });
    db = {
      googleIdentity: { findUnique: jest.fn(), create: jest.fn() },
      user: { findFirst: jest.fn(), create: jest.fn().mockResolvedValue(user) },
      refreshSession: { create: jest.fn() },
      playerProfile: { findUnique: jest.fn().mockResolvedValue(null) },
      $transaction: jest.fn((action) => action(db)),
    };
    service = new AuthService(db, {
      issuePair: async () => ({ accessToken: 'access', refreshToken: 'refresh' }),
      hashRefreshToken: () => 'hash',
    } as any);
  });

  afterEach(() => {
    verify.mockRestore();
    if (oldAudience === undefined) delete process.env.GOOGLE_SERVER_CLIENT_ID;
    else process.env.GOOGLE_SERVER_CLIENT_ID = oldAudience;
  });

  it('rejects unconfigured, invalid and unverified identity without creating a session', async () => {
    delete process.env.GOOGLE_SERVER_CLIENT_ID;
    await expect(service.loginGoogle('token')).rejects.toBeInstanceOf(ServiceUnavailableException);
    process.env.GOOGLE_SERVER_CLIENT_ID = 'test-audience';
    verify.mockRejectedValueOnce(new Error('wrong signature'));
    await expect(service.loginGoogle('token')).rejects.toBeInstanceOf(UnauthorizedException);
    verify.mockResolvedValueOnce({ getPayload: () => ({ ...identity, email_verified: false }) });
    await expect(service.loginGoogle('token')).rejects.toBeInstanceOf(UnauthorizedException);
    expect(db.refreshSession.create).not.toHaveBeenCalled();
  });

  it('attaches a new subject atomically and reuses the same user on repeat login', async () => {
    db.googleIdentity.findUnique.mockResolvedValueOnce(null).mockResolvedValueOnce({ onboardingPending: true }).mockResolvedValueOnce({ user }).mockResolvedValueOnce({ onboardingPending: false });
    await expect(service.loginGoogle('token')).resolves.toMatchObject({
      user: { id: 7 }, needsOnboarding: true,
    });
    db.playerProfile.findUnique.mockResolvedValue({ playingArea: 'Da Nang, Vietnam' });
    await expect(service.loginGoogle('token')).resolves.toMatchObject({
      user: { id: 7 }, needsOnboarding: false,
    });
    expect(verify).toHaveBeenCalledWith({ idToken: 'token', audience: 'test-audience' });
    expect(db.user.create).toHaveBeenCalledTimes(1);
    expect(db.user.create.mock.calls[0][0].data.googleIdentity).toEqual({ create: { subject: identity.sub, onboardingPending: true } });
    expect(db.refreshSession.create).toHaveBeenCalledTimes(2);
  });

  it('does not merge by email; linking requires the authenticated matching account', async () => {
    db.user.findFirst.mockResolvedValue(user);
    await expect(service.loginGoogle('token')).rejects.toBeInstanceOf(ConflictException);
    expect(db.user.create).not.toHaveBeenCalled();
    await expect(service.linkGoogle(7, 'token')).resolves.toEqual({ linked: true });
    expect(db.user.findFirst).toHaveBeenLastCalledWith({
      where: { id: 7, email: { equals: identity.email, mode: 'insensitive' } }, select: { id: true },
    });
    expect(db.googleIdentity.create).toHaveBeenCalledWith({ data: { userId: 7, subject: identity.sub } });
  });
  it('reports only the authenticated user link status', async () => {
    db.googleIdentity.findUnique.mockResolvedValueOnce(null).mockResolvedValueOnce({ userId: 7 });
    await expect(service.googleLinkStatus(7)).resolves.toEqual({ linked: false });
    await expect(service.googleLinkStatus(7)).resolves.toEqual({ linked: true });
    expect(db.googleIdentity.findUnique).toHaveBeenCalledWith({ where: { userId: 7 }, select: { userId: true } });
  });
  it('rejects mismatched emails without a link', async () => {
    db.user.findFirst.mockResolvedValue(null);
    await expect(service.linkGoogle(7, 'token')).rejects.toBeInstanceOf(ConflictException);
    expect(db.googleIdentity.create).not.toHaveBeenCalled();
  });

  it('does not onboard legacy linked users with missing area', async () => {
    db.googleIdentity.findUnique.mockResolvedValueOnce({ user }).mockResolvedValueOnce({ onboardingPending: false });
    await expect(service.loginGoogle('token')).resolves.toMatchObject({ needsOnboarding: false, user: { id: 7 } });
  });
  it('reports persistent pending and completed onboarding states', async () => {
    db.googleIdentity.findUnique.mockResolvedValueOnce({ onboardingPending: true }).mockResolvedValueOnce({ onboardingPending: false });
    await expect(service.googleOnboardingStatus(7)).resolves.toEqual({ needsOnboarding: true });
    await expect(service.googleOnboardingStatus(7)).resolves.toEqual({ needsOnboarding: false });
  });

});
